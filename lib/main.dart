// lib/main.dart
// Bitácora Web — Grilla propia editable con autosave, backup/import JSON y export XLSX.
// Sin SfDataGrid. TextFields controlados por celda. Enter mueve hacia abajo.
// Flutter Web. Null-safe.

import 'dart:async' show Timer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bitacora_web/services/local_store.dart';
import 'package:bitacora_web/services/export_xlsx_service.dart';

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
      fontFamilyFallback: const ['SF Pro Text', 'Inter', 'Roboto', 'Segoe UI', 'Helvetica', 'Arial'],
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
      home: Home(
        isLight: _light,
        onToggleTheme: () => setState(() => _light = !_light),
      ),
    );
  }
}

// -------------------- Modelo --------------------
class TableController {
  TableController() {
    final loaded = LocalStore.load();
    if (loaded != null && loaded.headers.isNotEmpty) {
      headers = List<String>.from(loaded.headers);
      rows = loaded.rows.map((r) => _padRow(r)).toList(growable: true);
    } else {
      headers = List<String>.from(_defaultHeaders);
      rows = List<List<String>>.generate(3, (_) => List<String>.filled(headers.length, ''));
    }
  }

  static const List<String> _defaultHeaders = <String>[
    'Fecha', 'Progresiva', 'Ω@1m', 'Ω@3m', 'Observaciones'
  ];

  late List<String> headers;
  late List<List<String>> rows;

  final Debouncer _debounce = Debouncer(const Duration(milliseconds: 300));
  TableState toState() => TableState(headers: headers, rows: rows, savedAt: DateTime.now());
  void saveDebounced() => _debounce(() => LocalStore.save(toState()));

  void addRow() {
    rows.add(List<String>.filled(headers.length, ''));
    saveDebounced();
  }

  void clearAll() {
    rows
      ..clear()
      ..addAll(List<List<String>>.generate(3, (_) => List<String>.filled(headers.length, '')));
    saveDebounced();
  }

  void renameHeader(int index, String newName) {
    if (index < 0 || index >= headers.length) return;
    headers[index] = newName.trim();
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

// -------------------- Grilla propia --------------------
class Home extends StatefulWidget {
  const Home({super.key, required this.isLight, required this.onToggleTheme});
  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late final TableController ctrl;

  // caches por celda
  final Map<String, TextEditingController> _ctls = {};
  final Map<String, FocusNode> _foci = {};
  bool zebra = true;
  bool showGridLines = true;

  static const double indexColW = 56;
  static const double colW = 180;
  static const double rowH = 38;
  static const double hdrH = 42;

  @override
  void initState() {
    super.initState();
    ctrl = TableController();
    _syncFromModel();
  }

  @override
  void dispose() {
    for (final c in _ctls.values) c.dispose();
    for (final f in _foci.values) f.dispose();
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
          ctl.addListener(() {
            ctrl.setCell(r, c, ctl.text); // sin setState
          });
          _ctls[key] = ctl;
        }
        _foci.putIfAbsent(key, () => FocusNode());
      }
    }
  }

  void _rebuildAllControllers() {
    for (final c in _ctls.values) c.dispose();
    for (final f in _foci.values) f.dispose();
    _ctls.clear();
    _foci.clear();
    _syncFromModel();
    setState(() {});
  }

  Future<void> _renameHeader(int i) async {
    final t = TextEditingController(text: ctrl.headers[i]);
    final r = await showDialog<String>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Renombrar columna'),
        content: TextField(controller: t, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, t.text.trim()), child: const Text('OK')),
        ],
      );
    });
    if (!mounted) return;
    if (r != null && r.isNotEmpty) {
      ctrl.renameHeader(i, r);
      setState(() {}); // solo encabezado
    }
  }

  void _onEnterMoveDown(int r, int c) {
    if (r == ctrl.rows.length - 1) {
      final anyFilled = ctrl.rows[r].any((v) => v.trim().isNotEmpty);
      if (anyFilled) {
        ctrl.addRow();
        _syncFromModel();
        setState(() {});
      }
    }
    final nextKey = _k((r + 1).clamp(0, ctrl.rows.length - 1), c);
    Future.microtask(() => _foci[nextKey]?.requestFocus());
  }

  Widget _buildHeaderCell(String text, {bool index = false, VoidCallback? onRename}) {
    return Container(
      height: hdrH,
      alignment: index ? Alignment.center : Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: index ? 0 : 12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? const Color(0xFFF9F9FB) : const Color(0xFF111827),
        border: showGridLines
            ? Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
          right: BorderSide(color: Theme.of(context).dividerColor),
        )
            : null,
      ),
      child: index
          ? Text(text, style: const TextStyle(fontWeight: FontWeight.w700))
          : GestureDetector(
        onDoubleTap: onRename,
        onLongPress: onRename,
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
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
      child: Text('${r + 1}', style: const TextStyle(fontSize: 13.5)),
    );
  }

  Widget _buildCell(int r, int c) {
    final key = _k(r, c);
    final ctl = _ctls[key]!;
    final node = _foci[key]!;
    final bg = zebra && r.isEven ? const Color(0x0C000000) : Colors.transparent;

    return Container(
      height: rowH,
      width: colW,
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
        child: TextField(
          controller: ctl,
          focusNode: node,
          maxLines: 1,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _onEnterMoveDown(r, c),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 13.5),
          cursorWidth: 1.2,
        ),
      ),
    );
  }

  Widget _grid() {
    final light = Theme.of(context).brightness == Brightness.light;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.8)),
        boxShadow: [
          if (light) const BoxShadow(blurRadius: 20, offset: Offset(0, 10), color: Color(0x15000000)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  _buildHeaderCell('#', index: true),
                  for (int c = 0; c < ctrl.headers.length; c++)
                    SizedBox(
                      width: colW,
                      child: _buildHeaderCell(
                        ctrl.headers[c],
                        onRename: () => _renameHeader(c),
                      ),
                    ),
                ],
              ),
              const Divider(height: 0, thickness: 0),

              // Body (sin Expanded)
              SizedBox(
                height: 420,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemExtent: rowH,
                  itemCount: ctrl.rows.length,
                  physics: const ClampingScrollPhysics(),
                  itemBuilder: (context, r) {
                    return Row(
                      children: [
                        _buildIndexCell(r),
                        for (int c = 0; c < ctrl.headers.length; c++) _buildCell(r, c),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportXlsx() async {
    await ExportXlsxService.download(
      filename: 'bitacora.xlsx',
      headers: ctrl.headers,
      rows: ctrl.rows,
    );
  }

  Future<void> _backupDownload() async {
    LocalStore.downloadBackup(ctrl.toState());
  }

  Future<void> _backupImport() async {
    final ts = await LocalStore.importBackup();
    if (ts == null) return;
    ctrl.headers = List<String>.from(ts.headers);
    ctrl.rows = ts.rows.map((r) => List<String>.from(r)).toList(growable: true);
    _rebuildAllControllers();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN): const _AddRowIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _AddRowIntent: CallbackAction<_AddRowIntent>(onInvoke: (intent) {
            ctrl.addRow();
            _syncFromModel();
            setState(() {});
            return null;
          }),
        },
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
                                  onPressed: () {
                                    widget.onToggleTheme();
                                    Navigator.pop(ctx);
                                  },
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
                onPressed: () {
                  ctrl.addRow();
                  _syncFromModel();
                  setState(() {});
                },
                icon: const Icon(Icons.add),
              ),
              IconButton(
                tooltip: 'Limpiar',
                onPressed: () {
                  ctrl.clearAll();
                  _rebuildAllControllers();
                },
                icon: const Icon(Icons.delete_sweep),
              ),
              IconButton(
                tooltip: 'Backup JSON',
                onPressed: _backupDownload,
                icon: const Icon(Icons.download),
              ),
              IconButton(
                tooltip: 'Importar JSON',
                onPressed: _backupImport,
                icon: const Icon(Icons.upload_file),
              ),
              IconButton(
                tooltip: 'Exportar XLSX',
                onPressed: _exportXlsx,
                icon: const Icon(Icons.file_download),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _grid(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddRowIntent extends Intent {
  const _AddRowIntent();
}

// --- Util ---
class Debouncer {
  Debouncer(this.duration);
  final Duration duration;
  Timer? _t;
  void call(void Function() action) {
    _t?.cancel();
    _t = Timer(duration, action);
  }
  void dispose() => _t?.cancel();
}
