// lib/screens/editor_screen.dart
// Editor tipo Excel con: auto-fit, backup/import JSON, export XLSX,
// adjuntos por fila y dictado de voz a la celda enfocada.

import 'dart:async';
import 'package:bitacora_web/services/speech_service.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/table_state.dart';
import '../services/export_xlsx_service.dart';
import '../services/local_store.dart';
import '../services/sheet_store.dart';
import '../services/speech_service.dart';
import '../utils/debouncer.dart';
import '../utils/history.dart';
import '../workers/json_worker.dart';
import '../widgets/attachments_button.dart';

import 'package:bitacora_web/services/speech_service.dart';
import 'package:bitacora_web/services/speech_service.dart';
import 'package:bitacora_web/services/speech_service.dart';
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
  static const double _indexColW = 56.0;
  static const double _minColW = 80.0;
  static const double _maxColW = 600.0;
  static const double _rowH = 38.0;
  static const double _hdrH = 42.0;

  late TableState _state;
  bool _loading = true;

  (int r, int c) _focus = (0, 0);
  bool _isEditing = false;

  final TextEditingController _cellEC = TextEditingController();
  final FocusNode _cellFN = FocusNode();
  final FocusNode _gridFN = FocusNode(debugLabel: 'gridFN');

  final Map<int, TextEditingController> _hdrCtl = {};
  late List<double> colWidths;
  List<double> _prefix = [];
  int _firstCol = 0;
  int _lastCol = 0;
  static const int _bufferCols = 2;
  double _lastViewportW = 0;
  bool _autoFitApplied = false;

  final _vScrollLeft = ScrollController();
  final _vScrollRight = ScrollController();
  bool _syncingV = false;

  final _hHeader = ScrollController();
  final _hBody = ScrollController();
  bool _syncingH = false;

  final _history = History<TableState>(cap: 200);
  final Debouncer _sheetDebounce = Debouncer(const Duration(milliseconds: 300));

  JsonWorker? _worker;

  // Anim
  double _editPulse = 0.0;

  // Modo Excel: al moverte, entra a editar.
  final bool _autoEditOnMove = true;

  int get _rowCount => _state.rows.length;
  int get _colCount => _state.headers.length;

  @override
  void initState() {
    super.initState();
    _state = TableState.empty();
    colWidths = List<double>.filled(_colCount, 180.0);
    _rebuildPrefix();

    _cellEC.addListener(_onCellTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _vScrollLeft.addListener(_syncFromLeft);
      _vScrollRight.addListener(_syncFromRight);
      _hHeader.addListener(_syncHFromHeader);
      _hBody.addListener(_syncHFromBody);
      _recomputeVisibleCols();
      _gridFN.requestFocus();
    });

    _hydrateFromStorage();
  }

  void _onCellTextChanged() {
    if (!_isEditing) return;
    setState(() => _editPulse += 1.0);
  }

  Future<void> _hydrateFromStorage() async {
    final raw = await _loadRawCompat(widget.sheetId);
    if (raw == null) {
      if (!mounted) return;
      setState(() {
        _state = TableState(
          headers: List.filled(5, ''),
          rows: List.generate(10, (_) => List.filled(5, '')),
          savedAt: DateTime.now(),
        );
        colWidths = List<double>.filled(5, 180.0);
        _rebuildPrefix();
        _loading = false;
      });
      return;
    }
    _worker = JsonWorker(
      onMeta: (headers, _) {
        if (!mounted) return;
        setState(() {
          _state = TableState(headers: headers, rows: const [], savedAt: DateTime.now());
          colWidths = List<double>.filled(_state.headers.length, 180.0);
          _rebuildPrefix();
        });
      },
      onRowsChunk: (chunk, done) {
        if (!mounted) return;
        setState(() {
          _state = _state.withAppendedRows(chunk);
          if (_loading && _state.rows.isNotEmpty) _loading = false;
        });
        if (done) {
          _sheetDebounce(() async {
            await LocalStore.save(_state);
            await _saveStateCompat(widget.sheetId, _state);
          });
        }
      },
      onError: (_) async {
        try {
          final parsed = TableState.fromJsonString(raw);
          if (!mounted) return;
          setState(() {
            _state = parsed ?? TableState.empty();
            colWidths = List<double>.filled(_state.headers.length, 180.0);
            _rebuildPrefix();
            _loading = false;
          });
        } catch (_) {
          if (mounted) setState(() => _loading = false);
        }
      },
    )..start(raw);
  }

  Future<String?> _loadRawCompat(String id) async {
    try {
      final dynamic r = SheetStore.loadRaw(id);
      if (r is Future<String?>) return await r;
      if (r is String?) return r;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveStateCompat(String id, TableState s) async {
    try {
      await Future.sync(() => SheetStore.saveState(id, s));
    } catch (_) {}
  }

  @override
  void dispose() {
    _worker?.dispose();
    _cellEC.removeListener(_onCellTextChanged);
    _cellEC.dispose();
    _cellFN.dispose();
    _gridFN.dispose();
    for (final c in _hdrCtl.values) {
      c.dispose();
    }
    _vScrollLeft.removeListener(_syncFromLeft);
    _vScrollRight.removeListener(_syncFromRight);
    _hHeader.removeListener(_syncHFromHeader);
    _hBody.removeListener(_syncHFromBody);
    _vScrollLeft.dispose();
    _vScrollRight.dispose();
    _hHeader.dispose();
    _hBody.dispose();
    _sheetDebounce.dispose();
    super.dispose();
  }

  void _resetHeaderControllers() {
    for (final c in _hdrCtl.values) {
      c.dispose();
    }
    _hdrCtl.clear();
  }

  TextEditingController _getHdrCtl(int col) {
    final existing = _hdrCtl[col];
    if (existing != null) return existing;
    final ctl = TextEditingController(text: _state.headers[col]);
    ctl.addListener(() {
      final newHeaders = List<String>.from(_state.headers)..[col] = ctl.text;
      final next = _state.withHeaders(newHeaders);
      _updateState(next, snapshot: false);
    });
    _hdrCtl[col] = ctl;
    return ctl;
  }

  void _rebuildPrefix() {
    _prefix = List<double>.filled(_colCount + 1, 0.0);
    for (int i = 0; i < _colCount; i++) {
      _prefix[i + 1] = _prefix[i] + colWidths[i];
    }
  }

  void _maybeAutoFitToViewport(double vw) {
    if (_autoFitApplied || _colCount == 0) return;
    final total = _prefix.isEmpty ? 0.0 : _prefix.last;
    if (total >= vw) return;
    final per = (vw / _colCount).clamp(_minColW, _maxColW).toDouble();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        colWidths = List<double>.filled(_colCount, per);
        _rebuildPrefix();
        _autoFitApplied = true;
      });
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
    if (end > _colCount) end = _colCount;
    start = (start - _bufferCols).clamp(0, _colCount - 1);
    end = (end + _bufferCols).clamp(0, _colCount);
    if (start > end) {
      start = 0;
      end = math.min(_colCount, 1);
    }
    final needSet = (start != _firstCol) || (end - 1 != _lastCol) || (vw != _lastViewportW);
    if (!needSet) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _firstCol = start;
        _lastCol = end - 1;
        _lastViewportW = vw;
      });
    });
  }

  void _syncFromLeft() {
    if (_syncingV || !_vScrollRight.hasClients) return;
    final want = _vScrollLeft.offset;
    if ((_vScrollRight.offset - want).abs() < 0.5) return;
    _syncingV = true;
    _vScrollRight.jumpTo(want);
    _syncingV = false;
  }

  void _syncFromRight() {
    if (_syncingV || !_vScrollLeft.hasClients) return;
    final want = _vScrollRight.offset;
    if ((_vScrollLeft.offset - want).abs() < 0.5) return;
    _syncingV = true;
    _vScrollLeft.jumpTo(want);
    _syncingV = false;
  }

  void _syncHFromHeader() {
    if (_syncingH || !_hBody.hasClients) return;
    final want = _hHeader.offset;
    if ((_hBody.offset - want).abs() < 0.5) return;
    _syncingH = true;
    _hBody.jumpTo(want);
    _syncingH = false;
    _recomputeVisibleCols();
  }

  void _syncHFromBody() {
    if (_syncingH || !_hHeader.hasClients) return;
    final want = _hBody.offset;
    if ((_hHeader.offset - want).abs() < 0.5) return;
    _syncingH = true;
    _hHeader.jumpTo(want);
    _syncingH = false;
    _recomputeVisibleCols();
  }

  void _updateState(TableState newState, {bool snapshot = true}) {
    final prevCols = _colCount;
    setState(() => _state = newState);
    if (snapshot) _history.push(_state);
    _sheetDebounce(() async {
      await LocalStore.save(newState);
      await _saveStateCompat(widget.sheetId, newState);
    });
    if (newState.headers.length != prevCols) {
      _resetHeaderControllers();
      colWidths = List<double>.filled(
        newState.headers.length,
        math.max(
          180.0,
          (_lastViewportW / (newState.headers.isEmpty ? 1 : newState.headers.length))
              .clamp(_minColW, _maxColW)
              .toDouble(),
        ),
      );
      _rebuildPrefix();
      _autoFitApplied = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeVisibleCols());
    }
  }

  void _setFocus(int r, int c) {
    r = r.clamp(0, _rowCount - 1);
    c = c.clamp(0, _colCount - 1);
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
  }

  void _enterEditing() {
    if (_isEditing) return;
    _gridFN.unfocus();
    final r = _focus.$1, c = _focus.$2;
    _cellEC.text = _state.rows[r][c];
    setState(() => _isEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cellFN.requestFocus();
      _cellEC.selection = TextSelection(baseOffset: 0, extentOffset: _cellEC.text.length);
    });
  }

  void _startEditing(int r, int c) {
    _setFocus(r, c);
    _enterEditing();
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

  void _commitCell(int r, int c, String newValue) {
    if (!_isEditing) return;
    setState(() => _isEditing = false);
    if (_state.rows[r][c] == newValue) {
      _gridFN.requestFocus();
      return;
    }
    _updateState(_state.withCell(r, c, newValue));
    _gridFN.requestFocus();
  }

  void _newRow() => _updateState(_state.withNewEmptyRow());

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
    _resetHeaderControllers();
  }

  void _undo() {
    final s = _history.undo();
    if (s != null) {
      _updateState(s, snapshot: false);
      _resetHeaderControllers();
    }
  }

  void _redo() {
    final s = _history.redo();
    if (s != null) {
      _updateState(s, snapshot: false);
      _resetHeaderControllers();
    }
  }

  Future<void> _exportXlsx() => ExportXlsxService.download(
    fileName: 'bitacora.xlsx',
    headers: _state.headers.toList(),
    rows: _state.rows.map((r) => r.toList()).toList(),
  );

  Future<void> _backupDownload() async => LocalStore.downloadBackup(_state);

  Future<void> _backupImport() async {
    final ts = await LocalStore.importBackup();
    if (!mounted || ts == null) return;
    final rows = ts.rows.isEmpty
        ? List.generate(3, (_) => List<String>.filled(ts.headers.length, ''))
        : ts.rows.map((r) => r.toList()).toList();
    _updateState(TableState(headers: ts.headers.toList(), rows: rows, savedAt: DateTime.now()));
    _resetHeaderControllers();
    _rebuildPrefix();
    _autoFitApplied = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeVisibleCols());
  }

  // Dictado a la celda enfocada
  Future<void> _dictateIntoFocusedCell() async {
    final (r, c) = _focus;
    if (_rowCount == 0 || _colCount == 0) return;
    if (!_isEditing) _startEditing(r, c);

    final ok = await SpeechService.I.init(preferredLocale: 'es_AR');
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Micrófono no disponible o permiso denegado')),
      );
      return;
    }

    await SpeechService.I.fillControllerOnce(
      _cellEC,
      localeId: SpeechService.I.currentLocale,
      autoTimeout: const Duration(seconds: 60),
    );
    if (!mounted) return;
    _commitCell(r, c, _cellEC.text);
  }

  // Teclado
  KeyEventResult _handleGridKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isEditing) return KeyEventResult.ignored;
    final (r, c) = _focus;

    // mover + edición inmediata
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      _setFocus(r + 1, c);
      if (_autoEditOnMove) _enterEditing();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      _setFocus(r - 1, c);
      if (_autoEditOnMove) _enterEditing();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _setFocus(r, c + 1);
      if (_autoEditOnMove) _enterEditing();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _setFocus(r, c - 1);
      if (_autoEditOnMove) _enterEditing();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.tab) {
      _setFocus(r, c + (_shiftDown() ? -1 : 1));
      if (_autoEditOnMove) _enterEditing();
      return KeyEventResult.handled;
    }

    // entrar a editar
    if (e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter ||
        e.logicalKey == LogicalKeyboardKey.f2 ||
        e.logicalKey == LogicalKeyboardKey.space ||
        e.logicalKey == LogicalKeyboardKey.select) {
      _startEditing(r, c);
      return KeyEventResult.handled;
    }

    // escribir para editar (sin Ctrl/Alt/Meta)
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final hasCtrl = keys.contains(LogicalKeyboardKey.controlLeft) || keys.contains(LogicalKeyboardKey.controlRight);
    final hasAlt = keys.contains(LogicalKeyboardKey.altLeft) || keys.contains(LogicalKeyboardKey.altRight);
    final hasMeta = keys.contains(LogicalKeyboardKey.metaLeft) || keys.contains(LogicalKeyboardKey.metaRight);

    final String? ch = e.character;
    if (!hasCtrl && !hasAlt && !hasMeta && ch != null && ch.isNotEmpty && ch.runes.length == 1) {
      _beginCharEdit(ch);
      return KeyEventResult.handled;
    }

    // borrar sin abrir editor
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

    return KeyEventResult.ignored;
  }

  bool _shiftDown() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.shiftLeft) || keys.contains(LogicalKeyboardKey.shiftRight);
  }

  void _ensureVisible(int r, int c) {
    if (_vScrollRight.hasClients) {
      final targetTop = r * _rowH;
      final targetBottom = targetTop + _rowH;
      final viewTop = _vScrollRight.offset;
      final viewBottom = viewTop + _vScrollRight.position.viewportDimension;
      if (targetTop < viewTop) {
        _vScrollRight.animateTo(targetTop, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
      } else if (targetBottom > viewBottom) {
        _vScrollRight.animateTo(
          targetBottom - _vScrollRight.position.viewportDimension,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    }
    if (_hBody.hasClients) {
      final x = _prefix[c];
      final cellW = colWidths[c];
      final viewX = _hBody.offset;
      final viewW = _hBody.position.viewportDimension;
      if (x < viewX) {
        _hBody.animateTo(x, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
      } else if (x + cellW > viewX + viewW) {
        _hBody.animateTo(x + cellW - viewW, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
      }
    }
  }

  double _measureText(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return tp.width;
  }

  void _autoFitColumn(int c) {
    final cellStyle = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    const hdrStyle = TextStyle(fontWeight: FontWeight.w700);
    double maxW = 0.0;
    final hdrText = _state.headers[c].isEmpty ? 'Col ${c + 1}' : _state.headers[c];
    maxW = math.max(maxW, _measureText(hdrText, hdrStyle));
    for (final row in _state.rows) {
      maxW = math.max(maxW, _measureText(row[c], cellStyle));
    }
    final target = (maxW + 24.0).clamp(_minColW, _maxColW).toDouble();
    setState(() {
      colWidths[c] = target;
      _rebuildPrefix();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeVisibleCols());
  }

  Widget _buildHeaderRow() {
    final bg = Theme.of(context).brightness == Brightness.light ? const Color(0xFFF9F9FB) : const Color(0xFF111827);
    return Container(
      height: _hdrH,
      color: bg.withOpacity(0.92),
      child: Row(children: [
        _buildIndexHeader(),
        Expanded(
          child: LayoutBuilder(builder: (_, cons) {
            final vw = cons.maxWidth;
            if (vw > 0) {
              _recomputeVisibleCols(vw);
              _maybeAutoFitToViewport(vw);
            }
            return SingleChildScrollView(
              controller: _hHeader,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _prefix.isEmpty ? vw : math.max(_prefix.last, vw),
                height: _hdrH,
                child: Row(children: [
                  SizedBox(width: _sumRange(0, _firstCol)),
                  for (int c = _firstCol; c <= _lastCol; c++) _buildHeaderCell(c),
                  SizedBox(width: _sumRange(_lastCol + 1, _colCount)),
                ]),
              ),
            );
          }),
        ),
      ]),
    );
  }

  Widget _buildIndexHeader() {
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

  Widget _buildHeaderCell(int c) {
    final titleColor = Theme.of(context).textTheme.titleMedium?.color;
    final hintColor = titleColor?.withOpacity(0.55);
    final bg = Theme.of(context).brightness == Brightness.light ? const Color(0xFFF9F9FB) : const Color(0xFF111827);
    final w = colWidths[c];
    final ctl = _getHdrCtl(c);
    return SizedBox(
      width: w,
      height: _hdrH,
      child: Stack(children: [
        Positioned.fill(
          right: 10.0,
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              color: bg.withOpacity(0.92),
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
              onSubmitted: (_) {
                _setFocus(0, c);
                _gridFN.requestFocus();
              },
            ),
          ),
        ),
        Positioned(
          right: 0.0,
          top: 0.0,
          bottom: 0.0,
          child: SizedBox(
            width: 10.0,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) {
                  setState(() {
                    final next = (colWidths[c] + d.delta.dx).clamp(_minColW, _maxColW);
                    colWidths[c] = next.toDouble();
                    _rebuildPrefix();
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeVisibleCols());
                },
                onDoubleTap: () => _autoFitColumn(c),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  double _sumRange(int a, int bExclusive) {
    if (_prefix.isEmpty) return 0.0;
    a = a.clamp(0, _colCount);
    bExclusive = bExclusive.clamp(0, _colCount);
    if (bExclusive < a) return 0.0;
    return _prefix[bExclusive] - _prefix[a];
  }

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const _NewRowIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ): const _UndoIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyY): const _RedoIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyL): const _ClearAllIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyD): const _DeleteRowIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyE): const _ExportIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyB): const _BackupIntent(),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyU): const _ImportIntent(),
        },
        child: Actions(
          actions: {
            _NewRowIntent: CallbackAction<_NewRowIntent>(onInvoke: (_) {
              _newRow();
              return null;
            }),
            _UndoIntent: CallbackAction<_UndoIntent>(onInvoke: (_) {
              _undo();
              return null;
            }),
            _RedoIntent: CallbackAction<_RedoIntent>(onInvoke: (_) {
              _redo();
              return null;
            }),
            _ClearAllIntent: CallbackAction<_ClearAllIntent>(onInvoke: (_) {
              _clearAll();
              return null;
            }),
            _DeleteRowIntent: CallbackAction<_DeleteRowIntent>(onInvoke: (_) {
              _deleteFocusedRow();
              return null;
            }),
            _ExportIntent: CallbackAction<_ExportIntent>(onInvoke: (_) {
              _exportXlsx();
              return null;
            }),
            _BackupIntent: CallbackAction<_BackupIntent>(onInvoke: (_) {
              _backupDownload();
              return null;
            }),
            _ImportIntent: CallbackAction<_ImportIntent>(onInvoke: (_) {
              _backupImport();
              return null;
            }),
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Inicio',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
              ),
              title: const Text('Editor'),
              actions: [
                // Adjuntos por fila (usa la fila enfocada)
                AttachmentsButton(
                  getCurrentRow: () {
                    if (_rowCount == 0) return null;
                    return (widget.sheetId, _focus.$1);
                  },
                ),
                // Dictado a celda
                IconButton(
                  tooltip: 'Dictar a celda',
                  onPressed: _dictateIntoFocusedCell,
                  icon: const Icon(Icons.mic_none),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: Theme.of(context).brightness == Brightness.light ? 'Cambiar a oscuro' : 'Cambiar a claro',
                  onPressed: widget.onToggleTheme,
                  icon: Icon(Theme.of(context).brightness == Brightness.light ? Icons.dark_mode : Icons.light_mode),
                ),
                IconButton(tooltip: 'Deshacer (Ctrl+Z)', onPressed: _undo, icon: const Icon(Icons.undo)),
                IconButton(tooltip: 'Rehacer (Ctrl+Y)', onPressed: _redo, icon: const Icon(Icons.redo)),
                IconButton(tooltip: 'Backup JSON (Ctrl+B)', onPressed: _backupDownload, icon: const Icon(Icons.download)),
                IconButton(tooltip: 'Importar JSON (Ctrl+U)', onPressed: _backupImport, icon: const Icon(Icons.upload_file)),
                IconButton(tooltip: 'Exportar XLSX (Ctrl+E)', onPressed: _exportXlsx, icon: const Icon(Icons.table_view)),
              ],
            ),
            body: SafeArea(
              child: _loading
                  ? const _EditorSkeleton()
                  : Column(children: [
                _buildHeaderRow(),
                const Divider(height: 1.0, thickness: 0.0),
                Expanded(child: _buildGridBody()),
              ]),
            ),
            floatingActionButton: _loading
                ? null
                : FloatingActionButton.extended(
                onPressed: _newRow, label: const Text('Fila'), icon: const Icon(Icons.add)),
          ),
        ),
      ),
    );
  }

  Widget _buildGridBody() {
    final bgOdd =
    Theme.of(context).brightness == Brightness.light ? const Color(0xFFFDFDFE) : const Color(0xFF0F1522);
    return Focus(
      autofocus: true,
      skipTraversal: true,
      focusNode: _gridFN,
      canRequestFocus: !_isEditing,
      onKeyEvent: _handleGridKey,
      child: Row(children: [
        SizedBox(
          width: _indexColW,
          child: ListView.builder(
            primary: false,
            controller: _vScrollLeft,
            itemExtent: _rowH,
            itemCount: _rowCount,
            itemBuilder: (context, r) {
              final selected = r == _focus.$1;
              final rowBg = (r.isOdd) ? bgOdd : Colors.transparent;
              return InkWell(
                onTap: () {
                  _setFocus(r, _focus.$2);
                  _gridFN.requestFocus();
                },
                child: Container(
                  alignment: Alignment.center,
                  color: rowBg,
                  child: Stack(fit: StackFit.expand, children: [
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
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2.0,
                            ),
                          ),
                        ),
                      ),
                  ]),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (_, cons) {
              final vw = cons.maxWidth;
              if (vw > 0) {
                _recomputeVisibleCols(vw);
                _maybeAutoFitToViewport(vw);
              }
              return SingleChildScrollView(
                controller: _hBody,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _prefix.isEmpty ? vw : math.max(_prefix.last, vw),
                  child: ListView.builder(
                    primary: false,
                    controller: _vScrollRight,
                    itemExtent: _rowH,
                    itemCount: _rowCount,
                    itemBuilder: (context, r) {
                      final rowBg = (r.isOdd) ? bgOdd : Colors.transparent;
                      return Container(
                        color: rowBg,
                        child: Row(children: [
                          SizedBox(width: _sumRange(0, _firstCol)),
                          for (int c = _firstCol; c <= _lastCol; c++) _buildDataCell(r, c),
                          SizedBox(width: _sumRange(_lastCol + 1, _colCount)),
                        ]),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildDataCell(int r, int c) {
    final w = colWidths[c];
    final isFocused = _focus.$1 == r && _focus.$2 == c;
    final text = _state.rows[r][c];

    Widget content;
    if (_isEditing && isFocused) {
      final tf = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: TextField(
          key: ValueKey('cell_editor_${r}_$c'),
          focusNode: _cellFN,
          controller: _cellEC,
          autofocus: true,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.none,
          autocorrect: false,
          enableSuggestions: false,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
          onTapOutside: (_) => _commitCell(r, c, _cellEC.text),
          onEditingComplete: () {},
        ),
      );

      content = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): () {
            _commitCell(r, c, _cellEC.text);
            _setFocus(r + (_shiftDown() ? -1 : 1), c);
          },
          const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
            _commitCell(r, c, _cellEC.text);
            _setFocus(r + (_shiftDown() ? -1 : 1), c);
          },
          const SingleActivator(LogicalKeyboardKey.tab): () {
            _commitCell(r, c, _cellEC.text);
            _setFocus(r, c + (_shiftDown() ? -1 : 1));
          },
          const SingleActivator(LogicalKeyboardKey.escape): () {
            setState(() => _isEditing = false);
            _gridFN.requestFocus();
          },
        },
        child: tf
            .animate(target: _editPulse)
            .scale(
          begin: const Offset(0.98, 0.98),
          end: const Offset(1.0, 1.0),
          duration: 120.ms,
          curve: Curves.easeOutBack,
        ),
      );
    } else {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            key: ValueKey('cell_${r}_${c}_${text.hashCode}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ).animate().fadeIn(duration: 120.ms);
    }

    final isActive = isFocused && !_isEditing;

    return SizedBox(
      width: w,
      height: _rowH,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (isFocused && !_isEditing) {
            _startEditing(r, c);
          } else {
            _setFocus(r, c);
            _gridFN.requestFocus();
          }
        },
        onDoubleTap: () => _startEditing(r, c),
        child: AnimatedContainer(
          duration: 120.ms,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
              right: BorderSide(color: Theme.of(context).dividerColor),
            ),
            boxShadow: isActive
                ? [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.20),
                blurRadius: 6.0,
                spreadRadius: 0.5,
              )
            ]
                : const [],
          ),
          child: Stack(fit: StackFit.expand, children: [
            content,
            if (isActive)
              IgnorePointer(
                child: AnimatedContainer(
                  duration: 120.ms,
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2.0),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ---- Intents
class _NewRowIntent extends Intent {
  const _NewRowIntent();
}
class _UndoIntent extends Intent {
  const _UndoIntent();
}
class _RedoIntent extends Intent {
  const _RedoIntent();
}
class _ClearAllIntent extends Intent {
  const _ClearAllIntent();
}
class _DeleteRowIntent extends Intent {
  const _DeleteRowIntent();
}
class _ExportIntent extends Intent {
  const _ExportIntent();
}
class _BackupIntent extends Intent {
  const _BackupIntent();
}
class _ImportIntent extends Intent {
  const _ImportIntent();
}

class _EditorSkeleton extends StatelessWidget {
  const _EditorSkeleton();
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      LinearProgressIndicator(minHeight: 2.0),
      const Spacer(),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 18.0, height: 18.0, child: CircularProgressIndicator(strokeWidth: 2.6)),
          const SizedBox(width: 10.0),
          const Text('Abriendo planilla…'),
        ],
      ),
      const Spacer(),
    ]);
  }
}



