# Auditoría rápida - Flutter/Dart

**Archivos Dart**: 
43
**Líneas aprox**: 
4533
**TODO/FIXME**: 
0
**// ignore:** 
0
**await → setState()**: 
9
  _(verificar mounted y no usar context tras await)_
**await → context**: 
13
  _(evitar context después de awaits; usar if (!mounted) return;)_
**if (!mounted) return;**: 
16
**withOpacity() (deprecado)**: 
10
**withValues()**: 
7

## Top imports
- import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/table_state.dart';

/// Metadata para listar planillas.
class SheetMeta {
  final String id;
  final DateTime updatedAt;
  final String title;
  final int rows;
  const SheetMeta({
    required this.id,
    required this.updatedAt,
    required this.title,
    required this.rows,
  });
}

/// Plantillas opcionales.
enum TemplateKind { resistividades, inventario, checklist }

class SheetStore {
  static const _indexKey = 'sheets:index'; // JSON: {"ids": [...]}
  static SharedPreferences? _prefs;

  /// Llamar una vez al inicio (ver main()).
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// JSON raw guardado.
  static String? loadRaw(String id) => _prefs?.getString('sheet:$id');

  /// Guarda estado y garantiza presencia en el Ã­ndice.
  static void saveState(String id, TableState state) {
    final fixed = TableState(
      headers: state.headers,
      rows: state.rows,
      savedAt: DateTime.now(),
    );
    final json = fixed.toJsonString();
    _prefs?.setString('sheet:$id', json);

    final ids = _getIndex();
    if (!ids.contains(id)) {
      ids.insert(0, id);
      _saveIndex(ids);
    }
  }

  /// Renombrar (se guarda separado para no tocar el JSON).
  static void rename(String id, String newTitle) {
    _prefs?.setString('sheet:$id:title', newTitle.trim());
  }

  static String? _readTitle(String id) => _prefs?.getString('sheet:$id:title');

  /// Crea hoja en blanco (5x3) y retorna id.
  static String createNew() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final state = TableState(
      headers: List<String>.filled(5, ''),
      rows: List.generate(3, (_) => List<String>.filled(5, '')),
      savedAt: DateTime.now(),
    );
    saveState(id, state);
    return id;
  }

  /// Crea hoja desde plantilla y retorna id.
  static String createFromTemplate(TemplateKind kind) {
    switch (kind) {
      case TemplateKind.resistividades:
        return _createWith(headers: const [
          'Fecha', 'Progresiva', '1 m (Î©)', '3 m (Î©)', '5 m (Î©)', 'Observaciones',
        ]);
      case TemplateKind.inventario:
        return _createWith(headers: const [
          'Item', 'Cantidad', 'Unidad', 'UbicaciÃ³n', 'Nota',
        ]);
      case TemplateKind.checklist:
        return _createWith(headers: const [
          'Tarea', 'Responsable', 'Estado', 'Hora', 'Comentario',
        ]);
    }
  }

  /// Elimina hoja y la saca del Ã­ndice (tambiÃ©n el tÃ­tulo).
  static void delete(String id) {
    _prefs?..remove('sheet:$id')..remove('sheet:$id:title');
    final ids = _getIndex()..remove(id);
    _saveIndex(ids);
  }

  /// Lista planillas ordenadas por fecha desc.
  static List<SheetMeta> list() {
    final ids = _getIndex();
    final out = <SheetMeta>[];
    for (final id in ids) {
      final raw = loadRaw(id);
      if (raw == null) continue;
      try {
        final ts = TableState.fromJsonString(raw);
        if (ts == null) continue;
        final custom = _readTitle(id);
        final derived = _firstNonEmpty(ts.headers) ?? '';
        final title = (custom != null && custom.trim().isNotEmpty)
            ? custom.trim()
            : derived;
        out.add(SheetMeta(
          id: id,
          updatedAt: ts.savedAt,
          title: title,
          rows: ts.rows.length,
        ));
      } catch (_) {
        // OJO: sin `const` porque DateTime.* no es constante.
        out.add(SheetMeta(
          id: id,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
          title: '',
          rows: 0,
        ));
      }
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  // ----------------- Helpers -----------------
  static List<String> _getIndex() {
    final raw = _prefs?.getString(_indexKey);
    if (raw == null) return <String>[];
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final ids = (map['ids'] as List).cast<String>();
      return ids;
    } catch (_) {
      return <String>[];
    }
  }

  static void _saveIndex(List<String> ids) {
    _prefs?.setString(_indexKey, jsonEncode({'ids': ids}));
  }

  static String _createWith({required List<String> headers}) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final state = TableState(
      headers: headers,
      rows: List.generate(3, (_) => List<String>.filled(headers.length, '')),
      savedAt: DateTime.now(),
    );
    saveState(id, state);
    return id;
  }

  static String? _firstNonEmpty(List<String> xs) {
    for (final x in xs) {
      if (x.trim().isNotEmpty) return x.trim();
    }
    return null;
  }
} — 1x
- import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/table_state.dart';

class SheetMeta {
  final String id;
  final DateTime updatedAt;
  final String title;
  final int rows;
  const SheetMeta(
      {required this.id,
      required this.updatedAt,
      required this.title,
      required this.rows});
}

class SheetStore {
  static const _indexKey = 'sheets:index:sp'; // {"ids":[...]}
  static Future<String?> loadRaw(String id) async {
    final p = await SharedPreferences.getInstance();
    return p.getString('sheet:$id');
  }

  static Future<void> saveState(String id, TableState state) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('sheet:$id', state.toJsonString());
    final ids = await _getIndex();
    if (!ids.contains(id)) {
      ids.insert(0, id);
      await _saveIndex(ids);
    }
  }

  static Future<void> rename(String id, String newTitle) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('sheet:$id:title', newTitle.trim());
  }

  static Future<String?> _readTitle(String id) async {
    final p = await SharedPreferences.getInstance();
    return p.getString('sheet:$id:title');
  }

  static Future<String> createNew() async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final s = TableState.empty();
    final p = await SharedPreferences.getInstance();
    await p.setString('sheet:$id', s.toJsonString());
    final ids = await _getIndex()
      ..insert(0, id);
    await _saveIndex(ids);
    return id;
  }

  static Future<String> ensureDefault() async {
    final ids = await _getIndex();
    if (ids.isEmpty) return createNew();
    return ids.first;
  }

  static Future<void> delete(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.remove('sheet:$id');
    await p.remove('sheet:$id:title');
    final ids = await _getIndex()
      ..remove(id);
    await _saveIndex(ids);
  }

  static Future<List<SheetMeta>> list() async {
    final ids = await _getIndex();
    final out = <SheetMeta>[];
    final p = await SharedPreferences.getInstance();
    for (final id in ids) {
      final raw = p.getString('sheet:$id');
      if (raw == null) continue;
      try {
        final ts = TableState.fromJsonString(raw);
        if (ts == null) continue;
        final custom = await _readTitle(id);
        final derived =
            ts.headers.firstWhere((h) => h.trim().isNotEmpty, orElse: () => '');
        final title = (custom != null && custom.trim().isNotEmpty)
            ? custom.trim()
            : derived;
        out.add(SheetMeta(
            id: id, updatedAt: ts.savedAt, title: title, rows: ts.rows.length));
      } catch (_) {
        out.add(SheetMeta(
            id: id,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            title: '',
            rows: 0));
      }
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  static Future<List<String>> _getIndex() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_indexKey);
    if (raw == null) return <String>[];
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return (map['ids'] as List).cast<String>();
    } catch (_) {
      return <String>[];
    }
  }

  static Future<void> _saveIndex(List<String> ids) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_indexKey, jsonEncode({'ids': ids}));
  }
} — 1x
- import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

class ShareService {
  static bool get _isMobile =>
      !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);

  /// savedPathOrName:
  /// - Web: abre el cliente de correo (mailto) sin adjunto (los navegadores no adjuntan).
  /// - Android/iOS: intenta adjuntar con flutter_email_sender, fallback a compartir o mailto.
  /// - Windows/macOS/Linux: comparte el archivo con share_plus; fallback mailto con la ruta en el cuerpo.
  static Future<void> sendExcel(String savedPathOrName) async {
    // WEB â†’ mailto sin adjunto
    if (kIsWeb) {
      final uri = Uri(
        scheme: 'mailto',
        queryParameters: const {
          'subject': 'BitÃ¡cora - ExportaciÃ³n XLSX',
          'body': 'Se descargÃ³ el archivo desde el navegador.',
        },
      );
      await launchUrl(uri);
      return;
    }

    // ANDROID/iOS â†’ adjunto real
    if (_isMobile) {
      try {
        final email = Email(
          body: 'Adjunto XLSX.',
          subject: 'BitÃ¡cora - ExportaciÃ³n',
          recipients: const [],
          attachmentPaths: [savedPathOrName],
          isHTML: false,
        );
        await FlutterEmailSender.send(email);
        return;
      } catch (_) {
        // sigue al fallback
      }
    }

    // DESKTOP (o fallback mobile) â†’ compartir archivo, y si falla, mailto con ruta
    try {
      await Share.shareXFiles([XFile(savedPathOrName)],
          text: 'BitÃ¡cora - ExportaciÃ³n');
    } catch (_) {
      final uri = Uri(
        scheme: 'mailto',
        queryParameters: {
          'subject': 'BitÃ¡cora - ExportaciÃ³n',
          'body':
          'No se pudo adjuntar automÃ¡ticamente.\nRuta del archivo: $savedPathOrName',
        },
      );
      await launchUrl(uri);
    }
  }
} — 1x
- import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> saveBytes(String fileName, List<int> bytes) async {
  final dir =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, fileName);
  final f = File(path);
  await f.writeAsBytes(bytes, flush: true);
  return path;
}

Future<String?> downloadBytesWeb(String name, List<int> bytes,
        {String mimeType = 'application/octet-stream'}) async =>
    null;
Future<String?> downloadTextWeb(String name, String text,
        {String mimeType = 'text/plain'}) async =>
    null;
Future<String?> pickTextFileWeb() async => null; — 1x
- import 'dart:typed_data';
import 'dart:html' as html;

Future<String> saveBytes(String fileName, List<int> bytes) async {
  final blob =
      html.Blob([Uint8List.fromList(bytes)], 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final a = html.AnchorElement(href: url)..download = fileName;
  a.click();
  html.Url.revokeObjectUrl(url);
  return fileName;
}

Future<String?> downloadBytesWeb(String name, List<int> bytes,
    {String mimeType = 'application/octet-stream'}) async {
  final blob = html.Blob([Uint8List.fromList(bytes)], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final a = html.AnchorElement(href: url)..download = name;
  a.click();
  html.Url.revokeObjectUrl(url);
  return name;
}

Future<String?> downloadTextWeb(String name, String text,
    {String mimeType = 'text/plain'}) async {
  final blob = html.Blob([text], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final a = html.AnchorElement(href: url)..download = name;
  a.click();
  html.Url.revokeObjectUrl(url);
  return name;
}

Future<String?> pickTextFileWeb() async {
  final input = html.FileUploadInputElement()
    ..accept = '.json,text/json,application/json';
  input.click();
  await input.onChange.first;
  final file = input.files?.first;
  if (file == null) return null;
  final reader = html.FileReader()..readAsText(file);
  await reader.onLoad.first;
  return reader.result as String?;
} — 1x
- import 'dart:convert';
import 'dart:html' as html;
import '../models/table_state.dart';

class SheetMeta {
  final String id;
  final DateTime updatedAt;
  final String title;
  final int rows;
  const SheetMeta(
      {required this.id,
      required this.updatedAt,
      required this.title,
      required this.rows});
}

class SheetStore {
  static const _indexKey = 'sheets:index'; // {"ids":[...]}

  static String? loadRaw(String id) => html.window.localStorage['sheet:$id'];

  static void saveState(String id, TableState state) {
    html.window.localStorage['sheet:$id'] = state.toJsonString();
    final ids = _getIndex();
    if (!ids.contains(id)) {
      ids.insert(0, id);
      _saveIndex(ids);
    }
  }

  static void rename(String id, String newTitle) {
    html.window.localStorage['sheet:$id:title'] = newTitle.trim();
  }

  static String? _readTitle(String id) =>
      html.window.localStorage['sheet:$id:title'];

  static String createNew() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final s = TableState.empty();
    html.window.localStorage['sheet:$id'] = s.toJsonString();
    final ids = _getIndex()..insert(0, id);
    _saveIndex(ids);
    return id;
  }

  static Future<String> ensureDefault() async {
    final ids = _getIndex();
    if (ids.isEmpty) return createNew();
    return ids.first;
  }

  static void delete(String id) {
    html.window.localStorage.remove('sheet:$id');
    html.window.localStorage.remove('sheet:$id:title');
    final ids = _getIndex()..remove(id);
    _saveIndex(ids);
  }

  static List<SheetMeta> list() {
    final ids = _getIndex();
    final out = <SheetMeta>[];
    for (final id in ids) {
      final raw = loadRaw(id);
      if (raw == null) continue;
      try {
        final ts = TableState.fromJsonString(raw);
        if (ts == null) continue;
        final custom = _readTitle(id);
        final derived =
            ts.headers.firstWhere((h) => h.trim().isNotEmpty, orElse: () => '');
        final title = (custom != null && custom.trim().isNotEmpty)
            ? custom.trim()
            : derived;
        out.add(SheetMeta(
            id: id, updatedAt: ts.savedAt, title: title, rows: ts.rows.length));
      } catch (_) {
        out.add(SheetMeta(
            id: id,
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
            title: '',
            rows: 0));
      }
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  static List<String> _getIndex() {
    final raw = html.window.localStorage[_indexKey];
    if (raw == null) return <String>[];
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return (map['ids'] as List).cast<String>();
    } catch (_) {
      return <String>[];
    }
  }

  static void _saveIndex(List<String> ids) {
    html.window.localStorage[_indexKey] = jsonEncode({'ids': ids});
  }
} — 1x
- import 'dart:async';
import 'dart:convert' as convert;

import '../models/table_state.dart';

/// Fallback sin Web Worker: parsea y emite en bloques sin congelar el frame.
class JsonWorker {
  JsonWorker({
    required this.onMeta,
    required this.onRowsChunk,
    required this.onError,
    this.chunkSize = 800,
  });

  final void Function(List<String> headers, int totalRows) onMeta;
  final void Function(List<List<String>> rowsChunk, bool done) onRowsChunk;
  final void Function(Object error) onError;
  final int chunkSize;

  void start(String rawJson) {
    // Microtask para evitar bloquear el frame actual.
    scheduleMicrotask(() {
      try {
        final obj = convert.jsonDecode(rawJson);
        if (obj is! Map) throw 'JSON invÃ¡lido (no es objeto)';
        final map = obj as Map<String, dynamic>;

        final headers = ((map['headers'] as List?) ?? const [])
            .map((e) => e?.toString() ?? '')
            .toList();

        final rows = ((map['rows'] as List?) ?? const [])
            .map((r) => (r is List ? r : const [])
                .map((e) => e?.toString() ?? '')
                .toList())
            .toList();

        onMeta(headers, rows.length);

        final ch = chunkSize;
        for (var i = 0; i < rows.length; i += ch) {
          final end = (i + ch < rows.length) ? i + ch : rows.length;
          final slice = rows.sublist(i, end);
          final done = end >= rows.length;
          onRowsChunk(slice, done);
        }
      } catch (e) {
        onError(e);
      }
    });
  }

  void dispose() {}

  /// Parseo one-shot directo (sin Worker).
  static Future<TableState> parseOnce(String rawJson,
      {int chunkSize = 800}) async {
    try {
      final obj = convert.jsonDecode(rawJson);
      if (obj is! Map) throw 'JSON invÃ¡lido (no es objeto)';
      final map = obj as Map<String, dynamic>;

      final headers = ((map['headers'] as List?) ?? const [])
          .map((e) => e?.toString() ?? '')
          .toList();

      final rows = ((map['rows'] as List?) ?? const [])
          .map((r) => (r is List ? r : const [])
              .map((e) => e?.toString() ?? '')
              .toList())
          .toList();

      return TableState(headers: headers, rows: rows, savedAt: DateTime.now());
    } catch (e) {
      return Future<TableState>.error(e);
    }
  }
} — 1x
- import 'dart:async';
import 'dart:convert' as convert;
import 'dart:html' as html;

import '../models/table_state.dart';

/// Wrapper para el worker JS en web/workers/json_parser_worker.js
class JsonWorker {
  JsonWorker({
    required this.onMeta,
    required this.onRowsChunk,
    required this.onError,
    this.chunkSize = 800,
    this.scriptUrl = 'workers/json_parser_worker.js',
  });

  final void Function(List<String> headers, int totalRows) onMeta;
  final void Function(List<List<String>> rowsChunk, bool done) onRowsChunk;
  final void Function(Object error) onError;

  final int chunkSize;
  final String scriptUrl;

  html.Worker? _worker;
  StreamSubscription<html.MessageEvent>? _sub;
  bool _closed = false;

  void start(String rawJson) {
    try {
      _worker = html.Worker(scriptUrl);
    } catch (e) {
      onError("No se pudo inicializar Worker: ");
      return;
    }

    _sub = _worker!.onMessage.listen((evt) {
      if (_closed) return;
      _handleRaw(evt.data);
    });

    // Inicia el worker
    _worker!.postMessage({
      'type': 'start',
      'raw': rawJson,
      'chunkSize': chunkSize,
    });
  }

  void _handleRaw(dynamic data) {
    try {
      Map<String, dynamic> m;
      if (data is String) {
        m = convert.jsonDecode(data) as Map<String, dynamic>;
      } else if (data is Map) {
        m = data.map((k, v) => MapEntry(k.toString(), v));
      } else {
        return;
      }
      _handleMap(m);
    } catch (e) {
      onError(e);
      dispose();
    }
  }

  void _handleMap(Map<String, dynamic> m) {
    final type = m['type'];
    if (type == 'meta') {
      final headers =
          (m['headers'] as List?)?.map((e) => e.toString()).toList() ??
              const <String>[];
      final total = (m['total'] as num?)?.toInt() ?? 0;
      onMeta(headers, total);
    } else if (type == 'chunk') {
      final rows = (m['rows'] as List?)
              ?.map((r) => (r as List).map((e) => e.toString()).toList())
              .toList() ??
          const <List<String>>[];
      final done = m['done'] == true;
      onRowsChunk(rows, done);
      if (done) dispose();
    } else if (type == 'error') {
      onError(m['message'] ?? 'worker error');
      dispose();
    }
  }

  void dispose() {
    _closed = true;
    try {
      _sub?.cancel();
    } catch (_) {}
    _sub = null;
    try {
      _worker?.terminate();
    } catch (_) {}
    _worker = null;
  }

  /// VersiÃ³n one-shot opcional (no la usamos mÃ¡s abajo, pero la dejo OK).
  static Future<TableState> parseOnce(
    String rawJson, {
    int chunkSize = 800,
    String scriptUrl = 'workers/json_parser_worker.js',
  }) async {
    final c = Completer<TableState>();
    final headers = <String>[];
    final rows = <List<String>>[];

    final w = JsonWorker(
      onMeta: (h, _) {
        headers
          ..clear()
          ..addAll(h);
      },
      onRowsChunk: (chunk, done) {
        rows.addAll(chunk);
        if (done && !c.isCompleted) {
          c.complete(TableState(
              headers: headers, rows: rows, savedAt: DateTime.now()));
        }
      },
      onError: (err) {
        if (!c.isCompleted) c.completeError(err);
      },
      chunkSize: chunkSize,
      scriptUrl: scriptUrl,
    );

    w.start(rawJson);
    return c.future;
  }
} — 1x
- import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class GlassAppBarBackground extends StatelessWidget {
  const GlassAppBarBackground({super.key, required this.isLight});
  final bool isLight;
  @override
  Widget build(BuildContext context) {
    final base = isLight ? Colors.white : const Color(0xFF0B1220);
    final border = isLight ? const Color(0x33000000) : const Color(0x33FFFFFF);
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: base.withValues(alpha: 0.72),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(height: 0.7, color: border),
          ),
        ),
      ),
    );
  }
} — 1x
- import 'dart:async';

class Debouncer {
  Debouncer(this.delay);
  final Duration delay;
  Timer? _t;
  void call(void Function() f) {
    _t?.cancel();
    _t = Timer(delay, f);
  }

  void dispose() => _t?.cancel();
} — 1x
- import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FloatingIconsLayer extends StatelessWidget {
  const FloatingIconsLayer({super.key});
  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final base = isLight ? Colors.black : Colors.white;
    final bubble = base.withValues(alpha: 0.06);
    const items =
        <({Alignment align, IconData icon, double size, int delayMs})>[
      (
        align: Alignment(-0.9, -0.8),
        icon: Icons.grid_view_rounded,
        size: 42,
        delayMs: 0
      ),
      (
        align: Alignment(0.85, -0.7),
        icon: Icons.table_chart_rounded,
        size: 50,
        delayMs: 200
      ),
      (
        align: Alignment(-0.75, 0.15),
        icon: Icons.description_outlined,
        size: 38,
        delayMs: 400
      ),
      (
        align: Alignment(0.75, 0.3),
        icon: Icons.send_rounded,
        size: 40,
        delayMs: 600
      ),
      (
        align: Alignment(-0.2, -0.05),
        icon: Icons.bolt_rounded,
        size: 36,
        delayMs: 800
      ),
      (
        align: Alignment(0.1, 0.85),
        icon: Icons.place_rounded,
        size: 44,
        delayMs: 1000
      ),
      (
        align: Alignment(-0.95, 0.8),
        icon: Icons.settings,
        size: 40,
        delayMs: 1200
      ),
    ];
    return IgnorePointer(
      ignoring: true,
      child: RepaintBoundary(
        child: Stack(
          children: [
            for (final it in items)
              Align(
                alignment: it.align,
                child: Container(
                  decoration:
                      BoxDecoration(color: bubble, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(10),
                  child: Icon(it.icon,
                      size: it.size,
                      color: Colors.white.withValues(alpha: 0.8)),
                )
                    .animate(
                        delay: Duration(milliseconds: it.delayMs),
                        onPlay: (c) => c.repeat(reverse: true))
                    .fadeIn(duration: 900.ms, curve: Curves.easeOut)
                    .moveY(
                        begin: 6,
                        end: -6,
                        duration: 3600.ms,
                        curve: Curves.easeInOut)
                    .then(delay: 0.ms)
                    .moveX(
                        begin: -4,
                        end: 4,
                        duration: 4200.ms,
                        curve: Curves.easeInOut),
              ),
          ],
        ),
      ),
    );
  }
} — 1x
- import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../workers/json_worker.dart';
import '../services/sheet_store.dart';
import '../services/export_xlsx_service.dart';
import '../widgets/glass_appbar.dart';
import '../widgets/floating_icons.dart';
import 'editor_screen.dart';

class StartPage extends StatefulWidget {
  const StartPage(
      {super.key, required this.isLight, required this.onToggleTheme});
  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  List<SheetMeta> _items = [];
  String _q = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _items = SheetStore.list());

  Future<void> _newSheet() async {
    final id = SheetStore.createNew();
    _reload();
    if (!mounted) return;
    await Navigator.push(
        context,
        _NoAnimRoute(
            child: EditorScreen(
          isLight: widget.isLight,
          onToggleTheme: widget.onToggleTheme,
          sheetId: id,
        )));
    _reload();
  }

  Future<void> _rename(SheetMeta m) async {
    final t = TextEditingController(text: m.title);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renombrar planilla'),
        content: TextField(
            controller: t,
            decoration: const InputDecoration(labelText: 'TÃ­tulo')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, t.text.trim()),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (!mounted) return;
    if (name != null) {
      SheetStore.rename(m.id, name);
      _reload();
    }
  }

  String _fmt(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'justo ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _exportSheet(SheetMeta m) async {
    final raw = SheetStore.loadRaw(m.id);
    if (raw == null) return;
    final parsed = await JsonWorker.parseOnce(raw);
    final name = _sanitizeFileName(m.title.isEmpty ? 'bitacora' : m.title);
    await ExportXlsxService.download(
      fileName: '$name.xlsx',
      headers: parsed.headers,
      rows: parsed.rows,
    );
  }

  String _sanitizeFileName(String s) {
    final r = RegExp(r'[\\/:*?"<>|]+');
    final cleaned = s.trim().replaceAll(r, '_');
    return cleaned.isEmpty ? 'bitacora' : cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _q.isEmpty
        ? _items
        : _items
            .where((e) => (e.title.isEmpty ? 'Planilla' : e.title)
                .toLowerCase()
                .contains(_q.toLowerCase()))
            .toList();
    final isLightTheme = Theme.of(context).brightness == Brightness.light;

    return Stack(
      children: [
        const FloatingIconsLayer(),
        Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('BitÃ¡cora Web'),
            flexibleSpace: GlassAppBarBackground(isLight: isLightTheme),
            actions: [
              IconButton(
                tooltip: isLightTheme ? 'Cambiar a oscuro' : 'Cambiar a claro',
                onPressed: widget.onToggleTheme,
                icon: Icon(isLightTheme ? Icons.dark_mode : Icons.light_mode),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: LayoutBuilder(
                  builder: (context, cons) {
                    final maxW = cons.maxWidth.isFinite
                        ? cons.maxWidth
                        : MediaQuery.of(context).size.width;
                    return SizedBox(
                      width: maxW,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).cardColor.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withOpacity(0.8)),
                              boxShadow: [
                                if (Theme.of(context).brightness ==
                                    Brightness.light)
                                  const BoxShadow(
                                      blurRadius: 20,
                                      offset: Offset(0, 10),
                                      color: Color(0x15000000)),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.table_chart, size: 28),
                                const SizedBox(width: 10),
                                const Expanded(
                                    child: Text(
                                        'Tus planillas, en un solo lugar',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18))),
                                FilledButton.icon(
                                    onPressed: _newSheet,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Nueva planilla')),
                              ],
                            ),
                          ).animate().fadeIn(duration: 320.ms).move(
                              begin: const Offset(0, 16),
                              curve: Curves.easeOut),
                          const SizedBox(height: 14),
                          TextField(
                            onChanged: (v) => setState(() => _q = v),
                            decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.search),
                                hintText: 'Buscar planillaâ€¦'),
                          )
                              .animate()
                              .fadeIn(duration: 280.ms, delay: 60.ms)
                              .move(
                                  begin: const Offset(0, 10),
                                  curve: Curves.easeOut),
                          const SizedBox(height: 14),
                          ...List.generate(filtered.length, (i) {
                            final m = filtered[i];
                            final card = Dismissible(
                              key: ValueKey(m.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                color: Theme.of(context)
                                    .colorScheme
                                    .errorContainer,
                                child: Icon(Icons.delete,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer),
                              ),
                              confirmDismiss: (_) async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Eliminar'),
                                    content: const Text(
                                        'Â¿Eliminar esta planilla? Esta acciÃ³n no se puede deshacer.'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancelar')),
                                      FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Eliminar')),
                                    ],
                                  ),
                                );
                                return ok ?? false;
                              },
                              onDismissed: (_) {
                                SheetStore.delete(m.id);
                                _reload();
                              },
                              child: Card(
                                elevation: 0,
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () async {
                                    await Navigator.push(
                                        context,
                                        _NoAnimRoute(
                                            child: EditorScreen(
                                          isLight: widget.isLight,
                                          onToggleTheme: widget.onToggleTheme,
                                          sheetId: m.id,
                                        )));
                                    _reload();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.description_outlined),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                m.title.isEmpty
                                                    ? 'Planilla sin tÃ­tulo'
                                                    : m.title,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700),
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            const SizedBox(height: 2),
                                            Text(
                                                '${m.rows} filas Â· ${_fmt(m.updatedAt)}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall),
                                          ],
                                        )),
                                        IconButton(
                                            tooltip: 'Exportar XLSX',
                                            onPressed: () => _exportSheet(m),
                                            icon: const Icon(Icons.table_view)),
                                        IconButton(
                                            tooltip: 'Renombrar',
                                            onPressed: () => _rename(m),
                                            icon: const Icon(Icons.edit_note)),
                                        IconButton(
                                            tooltip: 'Abrir',
                                            onPressed: () async {
                                              await Navigator.push(
                                                  context,
                                                  _NoAnimRoute(
                                                      child: EditorScreen(
                                                    isLight: widget.isLight,
                                                    onToggleTheme:
                                                        widget.onToggleTheme,
                                                    sheetId: m.id,
                                                  )));
                                              _reload();
                                            },
                                            icon: const Icon(
                                                Icons.arrow_forward)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                            return card
                                .animate(delay: (80 + i * 40).ms)
                                .fadeIn(duration: 260.ms)
                                .move(
                                    begin: const Offset(0, 10),
                                    curve: Curves.easeOut);
                          }),
                          if (filtered.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: Center(
                                  child: Text(
                                      'No hay planillas. Crea una nueva.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium)),
                            ).animate().fadeIn(duration: 240.ms),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _newSheet,
            label: const Text('Nueva'),
            icon: const Icon(Icons.add),
          )
              .animate()
              .fadeIn(duration: 280.ms, delay: 120.ms)
              .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
        ),
      ],
    );
  }
}

class _NoAnimRoute extends PageRouteBuilder {
  _NoAnimRoute({required Widget child})
      : super(
            pageBuilder: (_, __, ___) => child,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero);
} — 1x

## Archivos más largos
- C:\dev\bitacora_web\lib\screens\editor_screen.dart — 928 líneas
- C:\dev\bitacora_web\lib\smart_sheet\smart_sheet.dart — 375 líneas
- C:\dev\bitacora_web\lib\screens\start_page.dart — 340 líneas
- C:\dev\bitacora_web\lib\services\editor_boost.dart — 286 líneas
- C:\dev\bitacora_web\lib\widgets\command_palette.dart — 267 líneas
- C:\dev\bitacora_web\lib\models\table_state.dart — 262 líneas
- C:\dev\bitacora_web\lib\widgets\smart_datasource.dart — 203 líneas
- C:\dev\bitacora_web\lib\widgets\floating_icons_layer.dart — 187 líneas
- C:\dev\bitacora_web\lib\screens\sheets_screen.dart — 167 líneas
- C:\dev\bitacora_web\lib\services\sheet_store_io.dart — 147 líneas
- C:\dev\bitacora_web\lib\theme\gridnote_theme.dart — 130 líneas
- C:\dev\bitacora_web\lib\workers\json_worker_web.dart — 119 líneas
