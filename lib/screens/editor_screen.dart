// lib/screens/editor_screen.dart
// Editor tipo Excel. Android / iOS / Windows / Web.
// - Encabezados editables, auto-fit, resize con drag
// - Filas alternas, foco visible, edición al tocar
// - Adjuntos por fila y exportación XLSX real con fotos
// - Barra de adjuntos bajo encabezados, por fila enfocada
// - GPS y Dictado a celda
// - Backup/Import JSON, Undo/Redo, Agregar/Borrar fila/columna
// - Enviar por correo con fallbacks
// - Scroll con física tipo iOS en iOS/macOS (rebote) y clamping en el resto
// - Atajos extra: Tab/Shift+Tab, Ctrl/Cmd+S, Ctrl/Cmd+Z/Y, Ctrl/Cmd+N, Ctrl/Cmd+E

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:file_selector/file_selector.dart';
import 'package:geolocator/geolocator.dart' show LocationAccuracy;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import '../models/table_state.dart';
import '../services/local_store.dart';
import '../services/sheet_store.dart';
import '../services/attachments_service_web.dart';
import '../services/location_service.dart';
import '../services/speech_service.dart';
import '../services/xlsx_saver_io.dart'
if (dart.library.html) '../services/xlsx_saver_web.dart';
import '../services/mail_share_io.dart'
if (dart.library.html) '../services/mail_share_web.dart' as mail;
import '../utils/debouncer.dart';
import '../utils/history.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.isLight,
    required this.onToggleTheme,
    required this.sheetId,
  });
  final bool isLight;
  final VoidCallback onToggleTheme;
  final String sheetId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  // Layout
  static const double _indexColW = 56.0;
  static const double _minColW = 90.0;
  static const double _maxColW = 620.0;
  static const double _rowH = 40.0;
  static const double _hdrH = 46.0;
  static const double _attBarH = 88.0;

  static const int _initialCols = 8;
  static const int _initialRows = 6;

  late TableState _state;
  bool _loading = true;
  bool _busy = false;

  (int r, int c) _focus = (0, 0);
  bool _isEditing = false;

  final TextEditingController _cellEC = TextEditingController();
  final FocusNode _cellFN = FocusNode();
  final FocusNode _gridFN = FocusNode(debugLabel: 'gridFN');

  final Map<int, TextEditingController> _hdrCtl = {};
  late List<double> _colW;
  late List<double> _prefix;

  int _firstCol = 0;
  int _lastCol = 0;
  static const int _bufCols = 2;
  double _lastViewportW = 0;
  bool _autoFitOnce = false;

  bool _layoutOpsScheduled = false;
  double? _pendingViewportW;

  final _vIdx = ScrollController();
  final _vBody = ScrollController();
  bool _syncingV = false;

  final _hHdr = ScrollController();
  final _hBody = ScrollController();
  bool _syncingH = false;

  final _history = History<TableState>(cap: 200);
  final Debouncer _persistDebounce = Debouncer(const Duration(milliseconds: 250));

  final Map<int, int> _attachCounts = {};
  final Debouncer _attachDebounce = Debouncer(const Duration(milliseconds: 200));
  final Debouncer _attUiDebounce = Debouncer(const Duration(milliseconds: 120));

  // Barra de adjuntos (fila enfocada)
  List<_AttItem> _attOfFocused = const [];
  bool _attLoading = false;

  String? _lastSavedPath; // móvil/escritorio
  String? _lastSavedName; // web/móvil/escritorio

  @override
  void initState() {
    super.initState();
    _state = TableState.empty();
    _colW = List<double>.filled(0, 180);
    _prefix = List<double>.filled(0, 0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _vIdx.addListener(_syncFromIdx);
      _vBody.addListener(_syncFromBodyV);
      _hHdr.addListener(_syncFromHdr);
      _hBody.addListener(_syncFromBodyH);
      _hydrate();
    });
  }

  @override
  void dispose() {
    _cellEC.dispose();
    _cellFN.dispose();
    _gridFN.dispose();
    for (final c in _hdrCtl.values) {
      c.dispose();
    }
    _vIdx.removeListener(_syncFromIdx);
    _vBody.removeListener(_syncFromBodyV);
    _hHdr.removeListener(_syncFromHdr);
    _hBody.removeListener(_syncFromBodyH);
    _vIdx.dispose();
    _vBody.dispose();
    _hHdr.dispose();
    _hBody.dispose();
    _persistDebounce.dispose();
    super.dispose();
  }

  // ---------- state / storage ----------
  Future<void> _hydrate() async {
    final raw = await _loadRawCompat(widget.sheetId);
    if (!mounted) return;
    if (raw == null) {
      final headers = List<String>.generate(_initialCols, (i) => '');
      final rows = List.generate(_initialRows, (_) => List.filled(_initialCols, ''));
      setState(() {
        _state = TableState(headers: headers, rows: rows, savedAt: DateTime.now());
        _colW = List<double>.filled(headers.length, 180.0);
        _rebuildPrefix();
        _loading = false;
      });
      await _loadFocusedRowAttachments();
      return;
    }
    final parsed = TableState.fromJsonString(raw) ?? TableState.empty();
    if (!mounted) return;
    setState(() {
      _state = parsed;
      _colW = List<double>.filled(_state.headers.length, 180.0);
      _rebuildPrefix();
      _loading = false;
    });
    await _loadFocusedRowAttachments();
  }

  Future<String?> _loadRawCompat(String id) async {
    try {
      return await SheetStore.loadRaw(id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCompat(TableState s) async {
    await LocalStore.save(s);
    SheetStore.saveState(widget.sheetId, s);
  }

  void _updateState(TableState s, {bool snapshot = true}) {
    setState(() => _state = s);
    if (snapshot) _history.push(s);
    _persistDebounce(() => _saveCompat(s));
    if (_colW.length != s.headers.length) {
      _resetHdrCtl();
      _colW = List<double>.filled(
        s.headers.length,
        (_lastViewportW > 0 && s.headers.isNotEmpty)
            ? (_lastViewportW / s.headers.length).clamp(_minColW, _maxColW).toDouble()
            : 180.0,
      );
      _rebuildPrefix();
      _autoFitOnce = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeVisibleCols());
    }
  }

  void _resetHdrCtl() {
    for (final c in _hdrCtl.values) {
      c.dispose();
    }
    _hdrCtl.clear();
  }

  // ---------- layout helpers ----------
  void _rebuildPrefix() {
    _prefix = List<double>.filled(_colW.length + 1, 0);
    for (int i = 0; i < _colW.length; i++) {
      _prefix[i + 1] = _prefix[i] + _colW[i];
    }
  }

  void _maybeAutoFitViewport(double vw) {
    if (_autoFitOnce || _colW.isEmpty) return;
    final total = _prefix.last;
    if (total >= vw) return;
    final per = (vw / _colW.length).clamp(_minColW, _maxColW).toDouble();
    setState(() {
      for (int i = 0; i < _colW.length; i++) {
        _colW[i] = per;
      }
      _rebuildPrefix();
      _autoFitOnce = true;
    });
  }

  int _lowerBound(double x) {
    int lo = 0, hi = _prefix.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_prefix[mid] < x) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  void _recomputeVisibleCols([double? viewportW]) {
    if (!mounted) return;
    final hasBody = _hBody.hasClients;
    final vw = viewportW ?? (hasBody ? _hBody.position.viewportDimension : _lastViewportW);
    if (vw <= 0) return;
    final scrollX = hasBody ? _hBody.offset : 0.0;
    int start = _lowerBound(scrollX) - 1;
    if (start < 0) start = 0;
    final endLimit = scrollX + vw;
    int end = _lowerBound(endLimit);
    if (end > _colW.length) end = _colW.length;
    start = (start - _bufCols).clamp(0, _colW.isEmpty ? 0 : _colW.length - 1);
    end = (end + _bufCols).clamp(0, _colW.length);
    if (start > end) {
      start = 0;
      end = math.min(_colW.length, 1);
    }
    final need = start != _firstCol || end - 1 != _lastCol || vw != _lastViewportW;
    if (!need) return;
    setState(() {
      _firstCol = start;
      _lastCol = end - 1;
      _lastViewportW = vw;
    });
  }

  void _scheduleViewportOps(double vw) {
    _pendingViewportW = vw;
    if (_layoutOpsScheduled) return;
    _layoutOpsScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutOpsScheduled = false;
      if (!mounted) return;
      final x = _pendingViewportW;
      _pendingViewportW = null;
      if (x != null) {
        _recomputeVisibleCols(x);
        _maybeAutoFitViewport(x);
      }
    });
  }

  // ---------- scroll sync ----------
  void _syncFromIdx() {
    if (_syncingV || !_vBody.hasClients) return;
    final want = _vIdx.offset;
    if ((_vBody.offset - want).abs() < 0.5) return;
    _syncingV = true;
    _vBody.jumpTo(want);
    _syncingV = false;
  }

  void _syncFromBodyV() {
    if (_syncingV || !_vIdx.hasClients) return;
    final want = _vBody.offset;
    if ((_vIdx.offset - want).abs() < 0.5) return;
    _syncingV = true;
    _vIdx.jumpTo(want);
    _syncingV = false;
    _attachDebounce(_refreshAttachForVisible);
  }

  void _syncFromHdr() {
    if (_syncingH || !_hBody.hasClients) return;
    final want = _hHdr.offset;
    if ((_hBody.offset - want).abs() < 0.5) return;
    _syncingH = true;
    _hBody.jumpTo(want);
    _syncingH = false;
    _recomputeVisibleCols();
  }

  void _syncFromBodyH() {
    if (_syncingH || !_hHdr.hasClients) return;
    final want = _hBody.offset;
    if ((_hHdr.offset - want).abs() < 0.5) return;
    _syncingH = true;
    _hHdr.jumpTo(want);
    _syncingH = false;
    _recomputeVisibleCols();
  }

  // ---------- grid ops ----------
  int get _rowCount => _state.rows.length;
  int get _colCount => _state.headers.length;

  void _ensureColumn(int index) {
    if (index < _colCount) return;
    final add = index - _colCount + 1;
    final newH = List<String>.from(_state.headers)..addAll(List.filled(add, ''));
    final newR = _state.rows.map((r) => (List<String>.from(r)..addAll(List.filled(add, '')))).toList();
    _updateState(TableState(headers: newH, rows: newR, savedAt: DateTime.now()));
  }

  void _addColumnRightOfFocus() {
    final c = (_focus.$2 + 1).clamp(0, _colCount);
    final newH = <String>[];
    for (int i = 0; i < _colCount; i++) {
      newH.add(_state.headers[i]);
      if (i == _focus.$2) newH.add('');
    }
    final newR = _state.rows
        .map((r) {
      final nr = <String>[];
      for (int i = 0; i < r.length; i++) {
        nr.add(r[i]);
        if (i == _focus.$2) nr.add('');
      }
      return nr;
    })
        .toList();

    _updateState(TableState(headers: newH, rows: newR, savedAt: DateTime.now()));
    if (!mounted) return;
    setState(() {
      _colW.insert(c, 180.0);
      _rebuildPrefix();
    });
  }

  void _addRow() => _updateState(_state.withNewEmptyRow());

  void _deleteFocusedRow() {
    if (_rowCount <= 1) return;
    final r = _focus.$1.clamp(0, _rowCount - 1);
    final nextRows = <List<String>>[
      for (int i = 0; i < _rowCount; i++) if (i != r) _state.rows[i].toList(),
    ];
    _updateState(TableState(headers: _state.headers.toList(), rows: nextRows, savedAt: DateTime.now()));
    _setFocus((r - 1).clamp(0, _rowCount - 1), _focus.$2);
  }

  void _clearAll() {
    final cols = _state.headers.length;
    _updateState(TableState(
      headers: _state.headers.toList(),
      rows: List.generate(3, (_) => List<String>.filled(cols, '')),
      savedAt: DateTime.now(),
    ));
    _resetHdrCtl();
  }

  void _undo() {
    final s = _history.undo();
    if (s != null) {
      _updateState(s, snapshot: false);
      _resetHdrCtl();
    }
  }

  void _redo() {
    final s = _history.redo();
    if (s != null) {
      _updateState(s, snapshot: false);
      _resetHdrCtl();
    }
  }

  void _setFocus(int r, int c) {
    r = r.clamp(0, math.max(0, _rowCount - 1));
    c = c.clamp(0, math.max(0, _colCount - 1));
    final next = (r, c);
    if (_isEditing) _commitCell(_focus.$1, _focus.$2, _cellEC.text);
    if (_focus == next && !_isEditing) {
      _gridFN.requestFocus();
      return;
    }
    setState(() {
      _focus = next;
      _isEditing = false;
    });
    _gridFN.requestFocus();
    _ensureVisible(r, c);
    _attUiDebounce(_loadFocusedRowAttachments);
  }

  void _startEditing(int r, int c) {
    _setFocus(r, c);
    if (_isEditing) return;
    _gridFN.unfocus();
    _cellEC.text = _state.rows[r][c];
    setState(() => _isEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cellFN.requestFocus();
      _cellEC.selection = TextSelection(baseOffset: 0, extentOffset: _cellEC.text.length);
    });
  }

  void _commitCell(int r, int c, String v) {
    if (!_isEditing) return;
    setState(() => _isEditing = false);
    if (_state.rows[r][c] == v) {
      _gridFN.requestFocus();
      return;
    }
    _updateState(_state.withCell(r, c, v));
    _gridFN.requestFocus();
  }

  void _commitAndMoveDown(int r, int c) {
    _commitCell(r, c, _cellEC.text);
    final nextR = r + 1;
    if (nextR >= _rowCount) {
      _addRow();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startEditing(math.min(nextR, _rowCount - 1), c);
    });
  }

  void _beginCharEdit(String ch) {
    final (r, c) = _focus;
    _startEditing(r, c);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cellEC
        ..text = ch
        ..selection = TextSelection.collapsed(offset: ch.length);
    });
  }

  // ---------- header controls ----------
  TextEditingController _hdrController(int col) {
    final existing = _hdrCtl[col];
    if (existing != null) return existing;
    final ctl = TextEditingController(text: _state.headers[col]);
    ctl.addListener(() {
      final newH = List<String>.from(_state.headers)..[col] = ctl.text;
      _updateState(_state.withHeaders(newH), snapshot: false);
    });
    _hdrCtl[col] = ctl;
    return ctl;
  }

  void _autoFitCol(int c) {
    final cellStyle = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    const hdrStyle = TextStyle(fontWeight: FontWeight.w700);
    double maxW = 0;
    final hdr = _state.headers[c].isEmpty ? 'Col ${c + 1}' : _state.headers[c];
    maxW = math.max(maxW, _measureText(hdr, hdrStyle));
    for (final r in _state.rows) {
      maxW = math.max(maxW, _measureText(r[c], cellStyle));
    }
    final target = (maxW + 28.0).clamp(_minColW, _maxColW).toDouble();
    setState(() {
      _colW[c] = target;
      _rebuildPrefix();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeVisibleCols());
  }

  double _measureText(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return tp.width;
  }

  // ---------- index/body helpers ----------
  double _sumRange(int a, int bExclusive) {
    if (_prefix.isEmpty) return 0;
    a = a.clamp(0, _colCount);
    bExclusive = bExclusive.clamp(0, _colCount);
    if (bExclusive < a) return 0;
    return _prefix[bExclusive] - _prefix[a];
  }

  void _ensureVisible(int r, int c) {
    if (_vBody.hasClients) {
      final top = r * _rowH;
      final bottom = top + _rowH;
      final viewTop = _vBody.offset;
      final viewBottom = viewTop + _vBody.position.viewportDimension;
      if (top < viewTop) {
        _vBody.animateTo(top, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
      } else if (bottom > viewBottom) {
        _vBody.animateTo(bottom - _vBody.position.viewportDimension,
            duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
      }
    }
    if (_hBody.hasClients) {
      final x = _prefix[c];
      final w = _colW[c];
      final vx = _hBody.offset;
      final vw = _hBody.position.viewportDimension;
      if (x < vx) {
        _hBody.animateTo(x, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
      } else if (x + w > vx + vw) {
        _hBody.animateTo(x + w - vw, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
      }
    }
  }

  // ---------- adjuntos (conteo general) ----------
  Future<void> _refreshAttachForVisible() async {
    if (_rowCount == 0) return;
    final start = _firstVisibleRow();
    final end = math.min(_rowCount - 1, start + _visibleRowCount() + 4);
    for (var r = start; r <= end; r++) {
      final xs = await AttachmentsServiceWeb.I.listFor(sheetId: widget.sheetId, row: r);
      if (!mounted) return;
      final n = xs.length;
      if (_attachCounts[r] != n) {
        setState(() => _attachCounts[r] = n);
      }
    }
  }

  Future<void> _refreshAttachRow(int r) async {
    final xs = await AttachmentsServiceWeb.I.listFor(sheetId: widget.sheetId, row: r);
    if (!mounted) return;
    setState(() => _attachCounts[r] = xs.length);
  }

  int _firstVisibleRow() {
    if (!_vBody.hasClients) return 0;
    final off = _vBody.offset;
    return off <= 0 ? 0 : (off / _rowH).floor().clamp(0, _rowCount - 1);
  }

  int _visibleRowCount() {
    if (!_vBody.hasClients) return 0;
    final vh = _vBody.position.viewportDimension;
    if (vh <= 0) return 0;
    return (vh / _rowH).ceil();
  }

  // ---------- GPS / Speech ----------
  Future<void> _insertGpsHere() async {
    final (r, c) = _focus;
    await _insertGpsAt(r, c);
  }

  Future<void> _insertGpsRight() async {
    final (r, c) = _focus;
    await _insertGpsAt(r, c + 1);
  }

  Future<void> _insertGpsAt(int r, int cTarget) async {
    _ensureColumn(cTarget);
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);
    try {
      final fix = await LocationService.I.getCurrentFix(
        desiredAccuracy: LocationAccuracy.high,
        timeout: const Duration(seconds: 12),
      );
      if (!mounted) return;
      final buf = StringBuffer()
        ..write(fix.latitude.toStringAsFixed(6))
        ..write(', ')
        ..write(fix.longitude.toStringAsFixed(6));
      if (fix.accuracyMeters != null && fix.accuracyMeters! > 0) {
        buf.write(' ±${fix.accuracyMeters!.toStringAsFixed(0)} m');
      }
      _updateState(_state.withCell(r, cTarget, buf.toString()));
      _setFocus(r, cTarget);
      messenger?.showSnackBar(const SnackBar(content: Text('Ubicación insertada')));
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text('Error de ubicación: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dictateHere() async {
    final (r, c) = _focus;
    await _dictateAt(r, c);
  }

  Future<void> _dictateRight() async {
    final (r, c) = _focus;
    await _dictateAt(r, c + 1);
  }

  Future<void> _dictateAt(int r, int cTarget) async {
    _ensureColumn(cTarget);
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);
    try {
      final ok = await SpeechService.I.init(preferredLocale: 'es_AR');
      if (!mounted) return;
      if (!ok) {
        messenger?.showSnackBar(const SnackBar(content: Text('Micrófono no disponible')));
        return;
      }
      final text = await SpeechService.I.listenOnce(
        localeId: SpeechService.I.currentLocale,
        autoTimeout: const Duration(seconds: 60),
      );
      if (!mounted) return;
      if (text != null && text.trim().isNotEmpty) {
        _updateState(_state.withCell(r, cTarget, text.trim()));
        _setFocus(r, cTarget);
      }
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text('Error dictado: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- export XLSX + correo/compartir ----------
  Future<void> _exportXlsx() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);
    try {
      final bytes = await _buildXlsxBytesWithPhotos();
      final ts = _timestamp();
      final baseName = 'Gridnote_$ts';

      final savedPath = await saveXlsx(baseName, bytes); // path en móvil/escritorio, null en Web
      _lastSavedPath = savedPath;
      _lastSavedName = '$baseName.xlsx';

      if (!mounted) return;
      final msg = kIsWeb
          ? 'Descargado: $_lastSavedName'
          : (savedPath != null ? 'Guardado: $savedPath' : 'Guardado');
      messenger?.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) {
        messenger?.showSnackBar(SnackBar(content: Text('Error exportando: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendEmail() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);
    try {
      if (_lastSavedName == null && _lastSavedPath == null) {
        await _exportXlsx();
        if (!mounted) return;
      }
      final subject = 'Mediciones Gridnote ${DateTime.now().toIso8601String().substring(0, 10)}';
      final bodyBase = 'Adjunto XLSX generado desde Gridnote.';

      if (kIsWeb) {
        final body = _lastSavedName != null
            ? '$bodyBase\n\nAdjuntá manualmente: ${_lastSavedName!}'
            : bodyBase;
        await mail.sendMailWithFile(
          filePath: _lastSavedName ?? 'gridnote.xlsx', // usado solo como nombre en Web
          subject: subject,
          body: body,
        );
        if (!mounted) return;
        messenger?.showSnackBar(
          const SnackBar(content: Text('Se abrió el correo. Adjuntá el archivo descargado.')),
        );
      } else {
        if (_lastSavedPath == null) {
          await _exportXlsx();
          if (!mounted) return;
        }
        final p = _lastSavedPath!;
        await mail.sendMailWithFile(
          filePath: p,
          subject: subject,
          body: bodyBase,
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text('Error correo/compartir: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Uint8List> _buildXlsxBytesWithPhotos() async {
    final book = xlsio.Workbook();
    try {
      final sh = book.worksheets[0];
      // meta
      try {
        final p = book.builtInProperties;
        p.author = 'Gridnote';
        p.company = 'Gridnote';
        p.title = 'Exportación';
        p.subject = 'Planilla';
      } catch (_) {}

      // headers
      for (var c = 0; c < _colCount; c++) {
        final cell = sh.getRangeByIndex(1, c + 1);
        cell.setText(_state.headers[c]);
        final st = cell.cellStyle;
        st.bold = true;
        st.vAlign = xlsio.VAlignType.center;
        st.hAlign = xlsio.HAlignType.left;
      }

      // rows
      for (var r = 0; r < _rowCount; r++) {
        final row = _state.rows[r];
        for (var c = 0; c < _colCount && c < row.length; c++) {
          final v = row[c];
          final cell = sh.getRangeByIndex(r + 2, c + 1);
          final link = _mapsLinkOrNull(v);
          if (link != null) {
            cell.setText(v);
            sh.hyperlinks.add(cell, xlsio.HyperlinkType.url, link);
          } else {
            final raw = v.trim();
            final normalized = raw.replaceAll(',', '.');
            final d = double.tryParse(normalized);
            if (d != null && raw.isNotEmpty && !raw.contains(' ')) {
              cell.setNumber(d);
            } else {
              cell.setText(v);
            }
          }
        }
      }

      // Congelar encabezados
      try {
        sh.unfreezePanes();
      } catch (_) {}
      try {
        sh.getRangeByIndex(2, 1).freezePanes();
      } catch (_) {}

      // fotos por fila
      final Map<int, List<Uint8List>> byRow = {};
      for (var r = 0; r < _rowCount; r++) {
        final xs = await AttachmentsServiceWeb.I.listFor(sheetId: widget.sheetId, row: r);
        final imgs = xs
            .where((a) => (a as dynamic).mime.toLowerCase().startsWith('image/'))
            .map((a) => (a as dynamic).bytes as Uint8List)
            .toList();
        if (imgs.isNotEmpty) byRow[r] = imgs;
      }
      final maxPhotos = _maxPhotos(byRow, 3);
      final firstPhotoCol = _colCount + 1;
      const double kWpx = 160;
      const double kHpx = 120;
      final rowHeightsPx = List<double>.filled(_rowCount, 0);

      if (maxPhotos > 0) {
        for (var p = 0; p < maxPhotos; p++) {
          final col = firstPhotoCol + p;
          sh.getRangeByIndex(1, col).setText('Foto ${p + 1}');
          final st = sh.getRangeByIndex(1, col).cellStyle;
          st.bold = true;
          st.hAlign = xlsio.HAlignType.center;
          st.vAlign = xlsio.VAlignType.center;
          _columnRange(sh, col).columnWidth = 22.0;
        }
        byRow.forEach((r, list) {
          final take = math.min(list.length, maxPhotos);
          for (var p = 0; p < take; p++) {
            final col = firstPhotoCol + p;
            final pic = sh.pictures.addStream(r + 2, col, list[p]);
            pic.width = kWpx.toInt();
            pic.height = kHpx.toInt();
            rowHeightsPx[r] = math.max(rowHeightsPx[r], kHpx + 8);
          }
        });
        for (var r = 0; r < _rowCount; r++) {
          final px = rowHeightsPx[r];
          if (px > 0) {
            final pt = (px * 0.75) + 6.0;
            _rowRange(sh, r + 2).rowHeight = pt;
          }
        }
      }

      // estética + bordes + autofit
      final lastCol = _colCount + maxPhotos;
      final lastRow = _rowCount + 1;
      if (lastCol > 0 && lastRow > 0) {
        try {
          final used = sh.getRangeByIndex(1, 1, lastRow, lastCol);
          used.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        } catch (_) {}
      }
      for (var c = 1; c <= _colCount; c++) {
        try {
          sh.autoFitColumn(c);
        } catch (_) {
          try {
            _columnRange(sh, c).columnWidth = 18.0;
          } catch (_) {}
        }
      }
      try {
        sh.tableCollection.create('Datos', sh.getRangeByIndex(1, 1, lastRow, lastCol));
      } catch (_) {}

      final list = book.saveAsStream();
      return Uint8List.fromList(list);
    } finally {
      book.dispose();
    }
  }

  static String? _mapsLinkOrNull(String? t) {
    if (t == null) return null;
    final re = RegExp(
      r'^\\s*(-?\\d+(?:\\.\\d+)?),\\s*(-?\\d+(?:\\.\\d+)?)(?:\\s*[±+]\\s*\\d+\\s*m)?\\s*$',
      caseSensitive: false,
    );
    final m = re.firstMatch(t.trim());
    if (m == null) return null;
    final lat = m.group(1);
    final lon = m.group(2);
    if (lat == null || lon == null) return null;
    return 'https://maps.google.com/?q=$lat,$lon';
  }

  static int _maxPhotos(Map<int, List<Uint8List>> byRow, int maxPerRow) {
    var m = 0;
    byRow.forEach((_, list) {
      if (list.isNotEmpty) m = math.max(m, list.length);
    });
    return math.min(m, math.max(0, maxPerRow));
  }

  static xlsio.Range _columnRange(xlsio.Worksheet sh, int col) {
    final name = '\${_colName(col)}:\${_colName(col)}';
    return sh.getRangeByName(name);
  }

  static xlsio.Range _rowRange(xlsio.Worksheet sh, int row) {
    final name = '\$row:\$row';
    return sh.getRangeByName(name);
  }

  static String _colName(int idx) {
    var n = idx;
    final sb = StringBuffer();
    while (n > 0) {
      final rem = (n - 1) % 26;
      sb.writeCharCode(65 + rem);
      n = (n - 1) ~/ 26;
    }
    return sb.toString().split('').reversed.join();
  }

  static String _timestamp() {
    final d = DateTime.now();
    String t(int n) => n.toString().padLeft(2, '0');
    return '\${d.year}\${t(d.month)}\${t(d.day)}_\${t(d.hour)}\${t(d.minute)}\${t(d.second)}';
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Adjuntar a la fila',
            icon: const Icon(Icons.attach_file),
            onPressed: _pickAttachmentsForFocusedRow,
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'GPS en celda',
            icon: const Icon(Icons.my_location),
            onPressed: _busy ? null : _insertGpsHere,
          ),
          IconButton(
            tooltip: 'Dictar en celda',
            icon: const Icon(Icons.mic_none),
            onPressed: _busy ? null : _dictateHere,
          ),
          PopupMenuButton<String>(
            tooltip: 'Más inserciones',
            icon: const Icon(Icons.more_horiz),
            onSelected: (v) {
              if (v == 'gps_r') _insertGpsRight();
              if (v == 'mic_r') _dictateRight();
            },
            itemBuilder: (c) => const [
              PopupMenuItem(value: 'gps_r', child: ListTile(leading: Icon(Icons.place), title: Text('GPS a la derecha'))),
              PopupMenuItem(value: 'mic_r', child: ListTile(leading: Icon(Icons.keyboard_voice), title: Text('Dictar a la derecha'))),
            ],
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Nueva fila',
            icon: const Icon(Icons.add),
            onPressed: _addRow,
          ),
          IconButton(
            tooltip: 'Nueva columna',
            icon: const Icon(Icons.view_week_outlined),
            onPressed: _addColumnRightOfFocus,
          ),
          IconButton(
            tooltip: 'Borrar fila',
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteFocusedRow,
          ),
          const SizedBox(width: 6),
          IconButton(tooltip: 'Deshacer', icon: const Icon(Icons.undo), onPressed: _undo),
          IconButton(tooltip: 'Rehacer', icon: const Icon(Icons.redo), onPressed: _redo),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Backup JSON',
            icon: const Icon(Icons.download),
            onPressed: () => LocalStore.downloadBackup(_state),
          ),
          IconButton(
            tooltip: 'Importar JSON',
            icon: const Icon(Icons.upload_file),
            onPressed: _importBackup,
          ),
          PopupMenuButton<String>(
            tooltip: 'Herramientas',
            icon: const Icon(Icons.settings_outlined),
            onSelected: (v) {
              if (v == 'clear') _clearAll();
            },
            itemBuilder: (c) => const [
              PopupMenuItem(
                value: 'clear',
                child: ListTile(leading: Icon(Icons.cleaning_services), title: Text('Limpiar planilla')),
              ),
            ],
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Exportar XLSX',
            icon: const Icon(Icons.table_view),
            onPressed: _busy ? null : _exportXlsx,
          ),
          IconButton(
            tooltip: 'Enviar/Compartir',
            icon: const Icon(Icons.send),
            onPressed: _busy ? null : _sendEmail,
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: widget.isLight ? 'Modo oscuro' : 'Modo claro',
            icon: Icon(widget.isLight ? Icons.dark_mode : Icons.light_mode),
            onPressed: widget.onToggleTheme,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const _Skeleton()
          : ScrollConfiguration(
        behavior: const _PlatformScrollBehavior(),
        child: Column(
          children: [
            _buildHeader(cs),
            _buildAttachmentsBar(cs),
            const Divider(height: 1),
            Expanded(child: _buildBody(cs)),
          ],
        ),
      ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
        onPressed: _addRow,
        label: const Text('Fila'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    final bg = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFF7F7FA)
        : const Color(0xFF111827);
    return Container(
      height: _hdrH,
      color: bg.withOpacity(0.95),
      child: Row(
        children: [
          _indexHeader(cs),
          Expanded(
            child: LayoutBuilder(
              builder: (_, cons) {
                final vw = cons.maxWidth > 0 ? cons.maxWidth : MediaQuery.of(context).size.width;
                _scheduleViewportOps(vw);
                return SingleChildScrollView(
                  controller: _hHdr,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _prefix.isEmpty ? vw : math.max(_prefix.last, vw),
                    height: _hdrH,
                    child: Row(
                      children: [
                        SizedBox(width: _sumRange(0, _firstCol)),
                        for (int c = _firstCol; c <= _lastCol; c++) _headerCell(c, cs, bg),
                        SizedBox(width: _sumRange(_lastCol + 1, _colCount)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _indexHeader(ColorScheme cs) {
    return Container(
      width: _indexColW,
      height: _hdrH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: const Text('#', style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  Widget _headerCell(int c, ColorScheme cs, Color bg) {
    final titleColor = Theme.of(context).textTheme.titleMedium?.color;
    final hintColor = titleColor?.withOpacity(0.55);
    final w = _colW[c];
    final ctl = _hdrController(c);
    return SizedBox(
      width: w,
      height: _hdrH,
      child: Stack(
        children: [
          Positioned.fill(
            right: 10,
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: bg.withOpacity(0.95),
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                  right: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: TextField(
                controller: ctl,
                maxLines: 1,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Col ${c + 1}',
                  hintStyle: TextStyle(fontWeight: FontWeight.w600, color: hintColor),
                ),
                style: const TextStyle(fontWeight: FontWeight.w700),
                onSubmitted: (_) => _setFocus(0, c),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: 10,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) {
                    setState(() {
                      _colW[c] = (_colW[c] + d.delta.dx).clamp(_minColW, _maxColW).toDouble();
                      _rebuildPrefix();
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeVisibleCols());
                  },
                  onDoubleTap: () => _autoFitCol(c),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Barra de adjuntos ----------
  Widget _buildAttachmentsBar(ColorScheme cs) {
    final bg = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFF9FAFB)
        : const Color(0xFF0D1320);
    final r = _focus.$1;
    final cnt = _attOfFocused.length;
    return Container(
      height: _attBarH,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          SizedBox(
            width: _indexColW,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Fila', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
                Text('${r + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: _pickAttachmentsForFocusedRow,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(Icons.add_photo_alternate, size: 18, color: cs.primary),
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 10),
          Expanded(
            child: _attLoading
                ? const Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                : (cnt == 0
                ? Row(
              children: [
                Icon(Icons.photo_library_outlined, size: 18, color: Theme.of(context).hintColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sin fotos en la fila ${r + 1}. Tocá el ícono para adjuntar.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickAttachmentsForFocusedRow,
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: const Text('Adjuntar'),
                ),
              ],
            )
                : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < _attOfFocused.length; i++) _thumb(_attOfFocused[i], i),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: _pickAttachmentsForFocusedRow,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(96, 36)),
                  ),
                ],
              ),
            )),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.attach_file, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text('$cnt', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb(_AttItem a, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: InkWell(
        onTap: () => _showImageDialog(a.bytes, a.name),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).cardColor,
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.memory(
            a.bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            cacheWidth: 144,
            cacheHeight: 144,
            filterQuality: FilterQuality.low,
          ),
        ),
      ),
    );
  }

  Future<void> _showImageDialog(Uint8List bytes, String name) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              alignment: Alignment.centerLeft,
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            SizedBox(
              width: 420,
              height: 320,
              child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _loadFocusedRowAttachments() async {
    setState(() => _attLoading = true);
    try {
      final r = _focus.$1;
      final xs = await AttachmentsServiceWeb.I.listFor(sheetId: widget.sheetId, row: r);
      if (!mounted) return;
      final list = <_AttItem>[];
      for (final a in xs) {
        try {
          final mime = ((a as dynamic).mime as String?)?.toLowerCase() ?? 'application/octet-stream';
          if (!mime.startsWith('image/')) continue;
          final bytes = (a as dynamic).bytes as Uint8List;
          final name = (a as dynamic).name as String? ?? 'imagen';
          list.add(_AttItem(name: name, mime: mime, bytes: bytes));
        } catch (_) {}
      }
      setState(() => _attOfFocused = list);
      _attachCounts[r] = xs.length;
    } catch (_) {
      // silencioso
    } finally {
      if (mounted) setState(() => _attLoading = false);
    }
  }

  // ---------- body ----------
  Widget _buildBody(ColorScheme cs) {
    final bgOdd = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFFDFDFE)
        : const Color(0xFF0F1522);
    return Row(
      children: [
        SizedBox(
          width: _indexColW,
          child: ListView.builder(
            controller: _vIdx,
            physics: const AlwaysScrollableScrollPhysics(),
            itemExtent: _rowH,
            itemCount: _rowCount,
            itemBuilder: (context, r) {
              final selected = r == _focus.$1;
              final rowBg = r.isOdd ? bgOdd : Colors.transparent;
              final cnt = _attachCounts[r] ?? 0;
              return InkWell(
                onTap: () {
                  _setFocus(r, _focus.$2);
                  _gridFN.requestFocus();
                },
                child: Container(
                  color: rowBg,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Theme.of(context).dividerColor),
                            right: BorderSide(color: Theme.of(context).dividerColor),
                          ),
                        ),
                        child: Text(
                          '${r + 1}',
                          style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                        ),
                      ),
                      if (selected)
                        IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: cs.primary, width: 2),
                            ),
                          ),
                        ),
                      if (cnt > 0)
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.attach_file, size: 12, color: Colors.white),
                                const SizedBox(width: 2),
                                Text('$cnt',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (_, cons) {
              final vw = cons.maxWidth > 0 ? cons.maxWidth : MediaQuery.of(context).size.width;
              _scheduleViewportOps(vw);
              return SingleChildScrollView(
                controller: _hBody,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _prefix.isEmpty ? vw : math.max(_prefix.last, vw),
                  child: Focus(
                    autofocus: true,
                    skipTraversal: true,
                    focusNode: _gridFN,
                    canRequestFocus: !_isEditing,
                    onKeyEvent: _handleGridKey,
                    child: ListView.builder(
                      controller: _vBody,
                      itemExtent: _rowH,
                      itemCount: _rowCount,
                      itemBuilder: (context, r) {
                        final rowBg = r.isOdd ? bgOdd : Colors.transparent;
                        return Container(
                          color: rowBg,
                          child: Row(
                            children: [
                              SizedBox(width: _sumRange(0, _firstCol)),
                              for (int c = _firstCol; c <= _lastCol; c++) _cell(r, c, cs),
                              SizedBox(width: _sumRange(_lastCol + 1, _colCount)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _cell(int r, int c, ColorScheme cs) {
    final w = _colW[c];
    final focused = _focus.$1 == r && _focus.$2 == c;
    final text = _state.rows[r][c];

    final content = (_isEditing && focused)
        ? Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        key: ValueKey('cell_editor_${r}_$c'),
        focusNode: _cellFN,
        controller: _cellEC,
        autofocus: true,
        maxLines: 1,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.text,
        autocorrect: false,
        enableSuggestions: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        onTapOutside: (_) => _commitCell(r, c, _cellEC.text),
        onSubmitted: (_) => _commitAndMoveDown(r, c),
        onEditingComplete: () {},
      ),
    )
        : Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );

    return SizedBox(
      width: w,
      height: _rowH,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _startEditing(r, c),
        onDoubleTap: () => _startEditing(r, c),
        onLongPressStart: (d) async {
          _setFocus(r, c);
          final pick = await _showCellMenu(d.globalPosition);
          if (pick == null) return;
          switch (pick) {
            case _CellMenu.gpsRight:
              await _insertGpsAt(r, c + 1);
              break;
            case _CellMenu.speakRight:
              await _dictateAt(r, c + 1);
              break;
            case _CellMenu.gpsHere:
              await _insertGpsAt(r, c);
              break;
            case _CellMenu.speakHere:
              await _dictateAt(r, c);
              break;
            case _CellMenu.clear:
              _updateState(_state.withCell(r, c, ''));
              break;
          }
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
              right: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              content,
              if (focused && !_isEditing)
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: cs.primary, width: 2)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<_CellMenu?> _showCellMenu(Offset globalPos) {
    final pos = RelativeRect.fromLTRB(globalPos.dx, globalPos.dy, globalPos.dx, globalPos.dy);
    return showMenu<_CellMenu>(
      context: context,
      position: pos,
      items: const [
        PopupMenuItem(
          value: _CellMenu.gpsRight,
          child: ListTile(leading: Icon(Icons.my_location), title: Text('Ubicación a la derecha')),
        ),
        PopupMenuItem(
          value: _CellMenu.speakRight,
          child: ListTile(leading: Icon(Icons.mic), title: Text('Dictar a la derecha')),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _CellMenu.gpsHere,
          child: ListTile(leading: Icon(Icons.place), title: Text('Ubicación aquí')),
        ),
        PopupMenuItem(
          value: _CellMenu.speakHere,
          child: ListTile(leading: Icon(Icons.keyboard_voice_outlined), title: Text('Dictar aquí')),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _CellMenu.clear,
          child: ListTile(leading: Icon(Icons.clear), title: Text('Borrar celda')),
        ),
      ],
    );
  }

  // ---------- key handling ----------
  KeyEventResult _handleGridKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isEditing) return KeyEventResult.ignored;
    final (r, c) = _focus;

    // Navegación básica
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      _setFocus(r + 1, c);
      _startEditing(r + 1, c);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      _setFocus(r - 1, c);
      _startEditing(r - 1, c);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _setFocus(r, c + 1);
      _startEditing(r, c + 1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _setFocus(r, c - 1);
      _startEditing(r, c - 1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter ||
        e.logicalKey == LogicalKeyboardKey.f2 ||
        e.logicalKey == LogicalKeyboardKey.space ||
        e.logicalKey == LogicalKeyboardKey.select) {
      _startEditing(r, c);
      return KeyEventResult.handled;
    }

    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final hasCtrl = keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
    final hasShift = keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);

    // Tab / Shift+Tab
    if (e.logicalKey == LogicalKeyboardKey.tab) {
      if (hasShift) {
        _setFocus(r, c - 1);
        _startEditing(r, c - 1);
      } else {
        _setFocus(r, c + 1);
        _startEditing(r, c + 1);
      }
      return KeyEventResult.handled;
    }

    // Inicio de edición con caracter
    final String? ch = e.character;
    if (!hasCtrl && ch != null && ch.isNotEmpty && ch.runes.length == 1) {
      _beginCharEdit(ch);
      return KeyEventResult.handled;
    }

    // Borrar
    if (e.logicalKey == LogicalKeyboardKey.delete) {
      _updateState(_state.withCell(r, c, ''));
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _startEditing(r, c);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _cellEC.text = '';
      });
      return KeyEventResult.handled;
    }

    // Atajos
    if (hasCtrl && e.logicalKey == LogicalKeyboardKey.keyZ) {
      _undo();
      return KeyEventResult.handled;
    }
    if (hasCtrl && e.logicalKey == LogicalKeyboardKey.keyY) {
      _redo();
      return KeyEventResult.handled;
    }
    if (hasCtrl && e.logicalKey == LogicalKeyboardKey.keyN) {
      _addRow();
      return KeyEventResult.handled;
    }
    if (hasCtrl && e.logicalKey == LogicalKeyboardKey.keyE) {
      _exportXlsx();
      return KeyEventResult.handled;
    }
    if (hasCtrl && e.logicalKey == LogicalKeyboardKey.keyS) {
      _exportXlsx();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  // ---------- attachments picker ----------
  Future<void> _pickAttachmentsForFocusedRow() async {
    if (_rowCount == 0) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(const SnackBar(content: Text('No hay filas')));
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    final r = _focus.$1;
    try {
      final groupExt = XTypeGroup(label: 'Imágenes', extensions: const ['png', 'jpg', 'jpeg', 'webp', 'heic']);
      final groupMime = XTypeGroup(label: 'Imágenes', mimeTypes: const ['image/*']);
      final files = await openFiles(acceptedTypeGroups: [groupExt, groupMime]);
      if (files.isEmpty) return;

      for (final f in files) {
        try {
          await _attachmentsAddBytes(r: r, file: f);
        } catch (_) {}
      }
      if (!mounted) return;
      await _refreshAttachRow(r);
      await _loadFocusedRowAttachments();
      messenger?.showSnackBar(SnackBar(content: Text('Adjuntos agregados: \${files.length}')));
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(SnackBar(content: Text('No se pudo abrir el selector: $e')));
    }
  }

  Future<void> _attachmentsAddBytes({required int r, required XFile file}) async {
    final bytes = await file.readAsBytes();
    final name = file.name;
    final mime = _guessMime(name);
    final svc = AttachmentsServiceWeb.I;
    try {
      await (svc as dynamic).addBytes(
        sheetId: widget.sheetId,
        row: r,
        name: name,
        mime: mime,
        bytes: bytes,
      );
      return;
    } catch (_) {}
    try {
      await (svc as dynamic).add(
        sheetId: widget.sheetId,
        row: r,
        name: name,
        mime: mime,
        bytes: bytes,
      );
    } catch (_) {}
  }

  String _guessMime(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.heic')) return 'image/heic';
    return 'application/octet-stream';
  }

  // ---------- Backup Import ----------
  Future<void> _importBackup() async {
    final ts = await LocalStore.importBackup();
    if (!mounted || ts == null) return;
    final rows = ts.rows.isEmpty
        ? List.generate(3, (_) => List<String>.filled(ts.headers.length, ''))
        : ts.rows.map((r) => r.toList()).toList();
    _updateState(TableState(headers: ts.headers.toList(), rows: rows, savedAt: DateTime.now()));
    _resetHdrCtl();
    _rebuildPrefix();
    _autoFitOnce = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeVisibleCols());
    _attachDebounce(_refreshAttachForVisible);
    await _loadFocusedRowAttachments();
  }
}

// ----- Menú contextual -----
enum _CellMenu { gpsRight, speakRight, gpsHere, speakHere, clear }

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        LinearProgressIndicator(minHeight: 2),
        Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4)),
            SizedBox(width: 10),
            Text('Abriendo planilla…'),
          ],
        ),
        Spacer(),
      ],
    );
  }
}

// ----- tipos internos -----
class _AttItem {
  final String name;
  final String mime;
  final Uint8List bytes;
  const _AttItem({required this.name, required this.mime, required this.bytes});
}

// ----- ScrollBehavior específico por plataforma -----
class _PlatformScrollBehavior extends ScrollBehavior {
  const _PlatformScrollBehavior();
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    final platform = Theme.of(context).platform;
    switch (platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
      default:
        return const ClampingScrollPhysics();
    }
  }

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    // Sin glow para look moderno
    return child;
  }
}
