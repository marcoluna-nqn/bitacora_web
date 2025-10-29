// lib/main.dart
// Bitácora Web — Grilla editable con autosave, backup/import JSON y export XLSX.
// UX: Enter baja, Shift+Enter sube, Tab/Shift+Tab lateral, scroll vertical integrado a la página.
// Mejoras: undo/redo, copiar/pegar, duplicar fila, ir a fila, resize de columnas, índice fijo.
// Atajos: Ctrl+N (fila) | Ctrl+E (XLSX) | Ctrl+B (backup) | Ctrl+U (import) | Ctrl+L (limpiar)
//         Ctrl+D (borrar fila) | Ctrl+Shift+D (duplicar fila) | Ctrl+Z / Ctrl+Y (undo/redo) | Ctrl+G (ir a fila)
//         Ctrl+C / Ctrl+V (copiar/pegar celda)

import 'dart:async' show Timer;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/table_state.dart';
import 'services/local_store.dart';
import 'services/export_xlsx_service.dart';

void main() => runApp(const MyApp());

// -------------------- APP y tema --------------------
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _light = true;

  ThemeData _buildTheme(bool light) {
    const blue = Color(0xFF0A84FF);
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: light ? Brightness.light : Brightness.dark,
    );
    final scaffold = light ? const Color(0xFFF2F2F7) : const Color(0xFF0B1220);
    final card = light ? Colors.white : const Color(0xFF0E1624);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      cardColor: card,
      visualDensity: VisualDensity.compact,
      fontFamilyFallback: const ['SF Pro Text','Inter','Roboto','Segoe UI','Helvetica','Arial'],
      appBarTheme: AppBarTheme(
        backgroundColor: light ? Colors.white : const Color(0xFF0B1220),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: light ? Colors.black : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        iconTheme: IconThemeData(color: light ? Colors.black87 : Colors.white),
      ),
      dividerColor: light ? const Color(0xFFE5E5EA) : const Color(0xFF243043),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: blue, width: 1.4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bitácora Web',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(true),
      darkTheme: _buildTheme(false),
      themeMode: _light ? ThemeMode.light : ThemeMode.dark,
      home: Home(isLight: _light, onToggleTheme: () => setState(() => _light = !_light)),
    );
  }
}

// -------------------- Modelo --------------------
class TableController {
  static const int defaultCols = 5;

  TableController() {
    final loaded = LocalStore.load();
    if (loaded != null && loaded.headers.isNotEmpty) {
      headers = List<String>.from(loaded.headers);
      rows = loaded.rows.map((r) => _padRow(r)).toList(growable: true);
    } else {
      headers = List<String>.filled(defaultCols, '');
      rows = List<List<String>>.generate(3, (_) => List<String>.filled(headers.length, ''));
    }
  }

  late List<String> headers;
  late List<List<String>> rows;

  final Debouncer _debounce = Debouncer(const Duration(milliseconds: 300));
  TableState toState() => TableState(headers: headers, rows: rows, savedAt: DateTime.now());
  void saveDebounced() => _debounce(() => LocalStore.save(toState()));

  void addRow() {
    rows.add(List<String>.filled(headers.length, ''));
    saveDebounced();
  }

  void insertRowAt(int index) {
    final i = index.clamp(0, rows.length);
    rows.insert(i, List<String>.filled(headers.length, ''));
    saveDebounced();
  }

  void removeRow(int index) {
    if (rows.isEmpty) return;
    final i = index.clamp(0, rows.length - 1);
    rows.removeAt(i);
    if (rows.isEmpty) addRow();
    saveDebounced();
  }

  void clearAll() {
    rows
      ..clear()
      ..addAll(List<List<String>>.generate(3, (_) => List<String>.filled(headers.length, '')));
    saveDebounced();
  }

  void setHeader(int index, String text) {
    if (index < 0 || index >= headers.length) return;
    headers[index] = text;
    saveDebounced();
  }

  void setCell(int r, int c, String v) {
    if (r < 0 || r >= rows.length) return;
    if (c < 0 || c >= headers.length) return;
    final row = rows[r];
    if (row.length != headers.length) rows[r] = _padRow(row);
    rows[r][c] = v;
    saveDebounced();
  }

  String getCell(int r, int c) {
    if (r < 0 || r >= rows.length) return '';
    if (c < 0 || c >= headers.length) return '';
    final row = rows[r];
    if (c >= row.length) return '';
    return row[c];
  }

  List<String> _padRow(List<String> r) {
    final out = List<String>.from(r);
    if (out.length < headers.length) {
      out.addAll(List<String>.filled(headers.length - out.length, ''));
    } else if (out.length > headers.length) {
      out.removeRange(headers.length, out.length);
    }
    return out;
  }
}

// -------------------- Historial undo/redo --------------------
class _History<T> {
  final int cap;
  final List<T> _stack = [];
  int _idx = -1;
  _History({this.cap = 200});

  void push(T v) {
    if (_idx < _stack.length - 1) {
      _stack.removeRange(_idx + 1, _stack.length);
    }
    _stack.add(v);
    if (_stack.length > cap) {
      _stack.removeAt(0);
    }
    _idx = _stack.length - 1; // apunta al último válido
  }

  T? undo() {
    if (_idx <= 0 || _stack.isEmpty) return null;
    _idx--;
    return _stack[_idx];
  }

  T? redo() {
    if (_idx >= _stack.length - 1 || _stack.isEmpty) return null;
    _idx++;
    return _stack[_idx];
  }
}

// -------------------- Grilla --------------------
class Home extends StatefulWidget {
  const Home({super.key, required this.isLight, required this.onToggleTheme});
  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  late final TableController ctrl;

  final Map<String, TextEditingController> _ctls = {};
  final Map<String, FocusNode> _foci = {};
  final Map<String, GlobalKey> _cellKeys = {};

  final List<TextEditingController> _hdrCtls = [];
  final List<FocusNode> _hdrFoci = [];

  // false = texto, true = numérico
  late List<bool> numericCols;
  late List<double> colWidths;

  bool zebra = true;
  bool showGridLines = true;

  int _focusR = -1;
  int _focusC = -1;

  final _vScroll = ScrollController();
  final _hScroll = ScrollController();

  static const double indexColW = 56;
  static const double minColW = 80;
  static const double maxColW = 600;
  static const double rowH = 38;
  static const double hdrH = 42;

  final _history = _History<TableState>(cap: 200);

  void _snapshot() {
    _history.push(
      TableState(
        headers: List<String>.from(ctrl.headers),
        rows: ctrl.rows.map((r) => List<String>.from(r)).toList(),
        savedAt: DateTime.now(),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    ctrl = TableController();
    numericCols = List<bool>.filled(ctrl.headers.length, false);
    colWidths = List<double>.filled(ctrl.headers.length, 180);
    _syncFromModel();
    _ensureHeaderControllers();
    _snapshot();
  }

  @override
  void dispose() {
    for (final c in _ctls.values) { c.dispose(); }
    for (final f in _foci.values) { f.dispose(); }
    for (final c in _hdrCtls) { c.dispose(); }
    for (final f in _hdrFoci) { f.dispose(); }
    _vScroll.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  String _k(int r, int c) => '$r:$c';

  void _syncFromModel() {
    for (int r = 0; r < ctrl.rows.length; r++) {
      for (int c = 0; c < ctrl.headers.length; c++) {
        final key = _k(r, c);
        final text = ctrl.getCell(r, c);
        if (_ctls.containsKey(key)) {
          final ctl = _ctls[key]!;
          if (ctl.text != text) ctl.text = text;
        } else {
          final ctl = TextEditingController(text: text);
          ctl.addListener(() => ctrl.setCell(r, c, ctl.text));
          _ctls[key] = ctl;
        }
        _foci.putIfAbsent(key, () => FocusNode());
        _cellKeys.putIfAbsent(key, () => GlobalKey());
      }
    }
  }

  void _ensureHeaderControllers() {
    for (final c in _hdrCtls) { c.dispose(); }
    for (final f in _hdrFoci) { f.dispose(); }
    _hdrCtls.clear();
    _hdrFoci.clear();
    for (int i = 0; i < ctrl.headers.length; i++) {
      final c = TextEditingController(text: ctrl.headers[i]);
      c.addListener(() { ctrl.setHeader(i, c.text); });
      _hdrCtls.add(c);
      _hdrFoci.add(FocusNode());
    }
  }

  void _rebuildAllControllers() {
    for (final c in _ctls.values) { c.dispose(); }
    for (final f in _foci.values) { f.dispose(); }
    _ctls.clear();
    _foci.clear();
    _cellKeys.clear();
    _syncFromModel();
    _ensureHeaderControllers();
    if (!mounted) return;
    setState(() {});
  }

  void _restore(TableState s) {
    ctrl.headers = List<String>.from(s.headers);
    ctrl.rows = s.rows.map((r) => List<String>.from(r)).toList(growable: true);
    numericCols = List<bool>.filled(ctrl.headers.length, false);
    if (colWidths.length != ctrl.headers.length) {
      colWidths = List<double>.filled(ctrl.headers.length, 180);
    }
    _rebuildAllControllers();
  }

  void _ensureRowOnEnter(int r) {
    if (r == ctrl.rows.length - 1) {
      final anyFilled = ctrl.rows[r].any((v) => v.trim().isNotEmpty);
      if (anyFilled) {
        ctrl.addRow();
        _syncFromModel();
        if (!mounted) return;
        setState(() {});
        _snapshot();
      }
    }
  }

  void _ensureVisible(int r, int c) {
    final key = _k(r, c);
    final ctx = _cellKeys[key]?.currentContext;
    if (ctx == null) return;

    // Vertical con scroll de la página
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.2,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );

    // Horizontal suave
    if (!_hScroll.hasClients) return;
    final targetX = indexColW + _sumWidthUntil(c);
    final viewX = _hScroll.offset;
    final viewW = _hScroll.position.viewportDimension;
    if (targetX < viewX) {
      final to = math.max(0.0, targetX);
      _hScroll.animateTo(
        to,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    } else if (targetX + colWidths[c] > viewX + viewW) {
      final to = math.min(
        (targetX + colWidths[c] - viewW),
        _hScroll.position.maxScrollExtent,
      );
      _hScroll.animateTo(
        to,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  void _moveFocus(int r, int c) {
    _focusR = r.clamp(0, ctrl.rows.length - 1);
    _focusC = c.clamp(0, ctrl.headers.length - 1);
    setState(() {}); // actualiza borde de foco
    final key = _k(_focusR, _focusC);
    Future.microtask(() {
      final node = _foci[key];
      final ctl  = _ctls[key];
      node?.requestFocus();
      if (ctl != null) {
        ctl.selection = TextSelection(baseOffset: 0, extentOffset: ctl.text.length);
      }
      _ensureVisible(_focusR, _focusC);
    });
  }

  // ---------- Celdas ----------
  Widget _buildHeaderCell(int c) {
    final hintColor = Theme.of(context).textTheme.titleMedium?.color?.withOpacity(0.55);
    final bg = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFF9F9FB) : const Color(0xFF111827);
    final w = colWidths[c];

    return SizedBox(
      width: w,
      height: hdrH,
      child: Stack(
        children: [
          // Contenido del header, dejando 10 px para el grip
          Positioned.fill(
            right: 10,
            child: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: bg,
                border: showGridLines
                    ? Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                  right: BorderSide(color: Theme.of(context).dividerColor),
                )
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hdrCtls[c],
                      focusNode: _hdrFoci[c],
                      maxLines: 1,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Col ${c + 1}',
                        hintStyle: TextStyle(fontWeight: FontWeight.w600, color: hintColor),
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      onSubmitted: (_) { _snapshot(); _moveFocus(0, c); },
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => numericCols[c] = !numericCols[c]),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        numericCols[c] ? '123' : 'Aa',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: numericCols[c] ? Colors.blue : Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Grip de resize con ancho fijo
          Positioned(
            right: 0, top: 0, bottom: 0,
            child: SizedBox(
              width: 10,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) {
                    setState(() {
                      final nw = (w + d.delta.dx);
                      colWidths[c] = nw.clamp(minColW, maxColW).toDouble();
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndexCell(int r, {bool header = false}) {
    final bg = zebra && !header && r.isEven ? const Color(0x0C000000) : Colors.transparent;
    return Container(
      height: header ? hdrH : rowH,
      width: indexColW,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: showGridLines
            ? Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
          right: BorderSide(color: Theme.of(context).dividerColor),
        )
            : null,
      ),
      child: Text(header ? '#' : '${r + 1}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildCell(int r, int c) {
    final key = _k(r, c);
    final ctl = _ctls[key]!;
    final node = _foci[key]!;
    final bg = zebra && r.isEven ? const Color(0x0C000000) : Colors.transparent;
    final w = colWidths[c];
    final inputFmt = numericCols[c]
        ? <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]'))]
        : const <TextInputFormatter>[];
    final focused = (_focusR == r && _focusC == c);

    return SizedBox(
      key: _cellKeys[key],
      height: rowH,
      width: w,
      child: Container(
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: bg,
          border: showGridLines
              ? Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor),
            right: BorderSide(color: Theme.of(context).dividerColor),
          )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: focused ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1) : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: CallbackShortcuts(
                bindings: <ShortcutActivator, VoidCallback>{
                  const SingleActivator(LogicalKeyboardKey.enter): () { _ensureRowOnEnter(r); _moveFocus(r + 1, c); _snapshot(); },
                  const SingleActivator(LogicalKeyboardKey.numpadEnter): () { _ensureRowOnEnter(r); _moveFocus(r + 1, c); _snapshot(); },
                  const SingleActivator(LogicalKeyboardKey.enter, shift: true): () { _moveFocus(r - 1, c); _snapshot(); },
                  const SingleActivator(LogicalKeyboardKey.tab): () { _moveFocus(r, c + 1); },
                  const SingleActivator(LogicalKeyboardKey.tab, shift: true): () { _moveFocus(r, c - 1); },
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () { _ensureRowOnEnter(r); _moveFocus(r + 1, c); },
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () { _moveFocus(r - 1, c); },
                  const SingleActivator(LogicalKeyboardKey.arrowRight): () { _moveFocus(r, c + 1); },
                  const SingleActivator(LogicalKeyboardKey.arrowLeft): () { _moveFocus(r, c - 1); },
                },
                child: TextField(
                  controller: ctl,
                  focusNode: node, // foco real en el TextField
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                  onTap: () { _focusR = r; _focusC = c; setState(() {}); },
                  onSubmitted: (_) { _ensureRowOnEnter(r); _moveFocus(r + 1, c); _snapshot(); },
                  inputFormatters: inputFmt,
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                  style: const TextStyle(fontSize: 13.5),
                  cursorWidth: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Layout con índice fijo y scroll horizontal ----------
  double _sumWidthUntil(int c) {
    double s = 0;
    for (int i = 0; i < c; i++) s += colWidths[i];
    return s;
  }

  double get _tableWidth {
    double s = 0;
    for (final w in colWidths) { s += w; }
    return indexColW + s;
  }

  Widget _grid() {
    final light = Theme.of(context).brightness == Brightness.light;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.8)),
        boxShadow: [if (light) const BoxShadow(blurRadius: 20, offset: Offset(0, 10), color: Color(0x15000000))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Índice fijo
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIndexCell(0, header: true),
                for (int r = 0; r < ctrl.rows.length; r++) _buildIndexCell(r),
              ],
            ),
            // Cuerpo scrolleable en X
            Expanded(
              child: SingleChildScrollView(
                controller: _hScroll,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(_tableWidth - indexColW, 0.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [for (int c = 0; c < ctrl.headers.length; c++) _buildHeaderCell(c)]),
                      const Divider(height: 0, thickness: 0),
                      // Sin scroll interno: usa el scroll vertical de la página
                      ListView.builder(
                        padding: EdgeInsets.zero,
                        itemExtent: rowH,
                        itemCount: ctrl.rows.length,
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemBuilder: (context, r) {
                          return Row(children: [for (int c = 0; c < ctrl.headers.length; c++) _buildCell(r, c)]);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _backupDownload() async => LocalStore.downloadBackup(ctrl.toState());

  Future<void> _backupImport() async {
    final ts = await LocalStore.importBackup();
    if (ts == null) return;
    _restore(ts);
    _snapshot();
  }

  void _duplicateFocusedRow() {
    if (_focusR < 0 || _focusR >= ctrl.rows.length) return;
    final copy = List<String>.from(ctrl.rows[_focusR]);
    ctrl.insertRowAt(_focusR + 1);
    for (int c = 0; c < ctrl.headers.length; c++) {
      ctrl.setCell(_focusR + 1, c, copy[c]);
    }
    _syncFromModel();
    setState(() {});
    _moveFocus(_focusR + 1, _focusC < 0 ? 0 : _focusC);
    _snapshot();
  }

  Future<void> _gotoRowDialog() async {
    final n = await showDialog<int>(
      context: context,
      builder: (_) {
        final t = TextEditingController();
        return AlertDialog(
          title: const Text('Ir a fila'),
          content: TextField(
            controller: t,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Número de fila'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, int.tryParse(t.text)), child: const Text('Ir')),
          ],
        );
      },
    );
    if (n != null && n > 0 && n <= ctrl.rows.length) {
      _moveFocus(n - 1, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isNarrow = w < 680;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const _AddRowIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyE): const _ExportIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyB): const _BackupIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyU): const _ImportIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyL): const _ClearIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyD): const _DeleteRowIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyZ): const _UndoIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyY): const _RedoIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyG): const _GotoIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyD): const _DupRowIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC): const _CopyIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyV): const _PasteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _AddRowIntent: CallbackAction<_AddRowIntent>(onInvoke: (intent) { ctrl.addRow(); _syncFromModel(); setState(() {}); _snapshot(); return null; }),
          _ExportIntent: CallbackAction<_ExportIntent>(onInvoke: (intent) { _exportXlsxImpl(ctrl.headers, ctrl.rows); return null; }),
          _BackupIntent: CallbackAction<_BackupIntent>(onInvoke: (intent) { _backupDownload(); return null; }),
          _ImportIntent: CallbackAction<_ImportIntent>(onInvoke: (intent) async { await _backupImport(); return null; }),
          _ClearIntent: CallbackAction<_ClearIntent>(onInvoke: (intent) { ctrl.clearAll(); _rebuildAllControllers(); _snapshot(); return null; }),
          _DeleteRowIntent: CallbackAction<_DeleteRowIntent>(onInvoke: (intent) {
            if (_focusR >= 0) {
              ctrl.removeRow(_focusR);
              _rebuildAllControllers();
              final r = (_focusR - 1).clamp(0, ctrl.rows.length - 1);
              _moveFocus(r, _focusC < 0 ? 0 : _focusC);
              _snapshot();
            }
            return null;
          }),
          _UndoIntent: CallbackAction<_UndoIntent>(onInvoke: (_) { final s = _history.undo(); if (s != null) _restore(s); return null; }),
          _RedoIntent: CallbackAction<_RedoIntent>(onInvoke: (_) { final s = _history.redo(); if (s != null) _restore(s); return null; }),
          _GotoIntent: CallbackAction<_GotoIntent>(onInvoke: (_) { _gotoRowDialog(); return null; }),
          _DupRowIntent: CallbackAction<_DupRowIntent>(onInvoke: (_) { _duplicateFocusedRow(); return null; }),
          _CopyIntent: CallbackAction<_CopyIntent>(onInvoke: (_) {
            if (_focusR>=0 && _focusC>=0) {
              Clipboard.setData(ClipboardData(text: ctrl.getCell(_focusR,_focusC)));
            }
            return null;
          }),
          _PasteIntent: CallbackAction<_PasteIntent>(onInvoke: (_) async {
            final data = await Clipboard.getData('text/plain');
            if (data?.text != null && _focusR>=0 && _focusC>=0) {
              ctrl.setCell(_focusR,_focusC,data!.text!);
              _ctls[_k(_focusR,_focusC)]?.text = data.text!;
              _snapshot();
              setState(() {});
            }
            return null;
          }),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Bitácora Web'),
              actions: [
                IconButton(
                  tooltip: 'Preferencias',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      useSafeArea: true,
                      showDragHandle: true,
                      builder: (ctx) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Text('Apariencia', style: TextStyle(fontWeight: FontWeight.w700)),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: widget.isLight ? 'Cambiar a oscuro' : 'Cambiar a claro',
                                    onPressed: () { widget.onToggleTheme(); Navigator.pop(ctx); },
                                    icon: Icon(widget.isLight ? Icons.dark_mode : Icons.light_mode),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Rayado alterno de filas'),
                                value: zebra,
                                onChanged: (v) => setState(() => zebra = v),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Líneas de grilla'),
                                value: showGridLines,
                                onChanged: (v) => setState(() => showGridLines = v),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.tune),
                ),
                IconButton(
                  tooltip: 'Tema',
                  onPressed: widget.onToggleTheme,
                  icon: Icon(widget.isLight ? Icons.dark_mode : Icons.light_mode),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Agregar fila (Ctrl+N)',
                  onPressed: () { ctrl.addRow(); _syncFromModel(); setState(() {}); _snapshot(); },
                  icon: const Icon(Icons.add),
                ),
                IconButton(
                  tooltip: 'Duplicar fila (Ctrl+Shift+D)',
                  onPressed: _duplicateFocusedRow,
                  icon: const Icon(Icons.content_copy),
                ),
                IconButton(
                  tooltip: 'Limpiar (Ctrl+L)',
                  onPressed: () { ctrl.clearAll(); _rebuildAllControllers(); _snapshot(); },
                  icon: const Icon(Icons.delete_sweep),
                ),
                IconButton(
                  tooltip: 'Backup JSON (Ctrl+B)',
                  onPressed: _backupDownload,
                  icon: const Icon(Icons.download),
                ),
                IconButton(
                  tooltip: 'Importar JSON (Ctrl+U)',
                  onPressed: _backupImport,
                  icon: const Icon(Icons.upload_file),
                ),
                IconButton(
                  tooltip: 'Exportar XLSX (Ctrl+E)',
                  onPressed: () => _exportXlsxImpl(ctrl.headers, ctrl.rows),
                  icon: const Icon(Icons.file_download),
                ),
              ],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                controller: _vScroll,
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: isNarrow ? const BoxConstraints() : const BoxConstraints(maxWidth: 1200),
                    child: _grid(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddRowIntent extends Intent { const _AddRowIntent(); }
class _ExportIntent extends Intent { const _ExportIntent(); }
class _BackupIntent extends Intent { const _BackupIntent(); }
class _ImportIntent extends Intent { const _ImportIntent(); }
class _ClearIntent extends Intent { const _ClearIntent(); }
class _DeleteRowIntent extends Intent { const _DeleteRowIntent(); }
class _UndoIntent extends Intent { const _UndoIntent(); }
class _RedoIntent extends Intent { const _RedoIntent(); }
class _GotoIntent extends Intent { const _GotoIntent(); }
class _DupRowIntent extends Intent { const _DupRowIntent(); }
class _CopyIntent extends Intent { const _CopyIntent(); }
class _PasteIntent extends Intent { const _PasteIntent(); }

// --- Util ---
class Debouncer {
  Debouncer(this.duration);
  final Duration duration;
  Timer? _t;
  void call(void Function() action) { _t?.cancel(); _t = Timer(duration, action); }
  void dispose() => _t?.cancel();
}

// --- Export XLSX ---
Future<void> _exportXlsxImpl(List<String> headers, List<List<String>> rows) {
  return ExportXlsxService.download(
    filename: 'bitacora.xlsx',
    headers: headers,
    rows: rows.map((r) => r.map((e) => e.toString()).toList()).toList(),
  );
}
