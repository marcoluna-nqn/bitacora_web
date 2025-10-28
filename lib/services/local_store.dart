// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html; // Web only
import 'dart:async';
import 'dart:convert';

const String _kStorageKey = 'bitacora_state_v1';

class TableState {
  final List<String> headers;
  final List<List<String>> rows;
  final DateTime savedAt;
  const TableState({required this.headers, required this.rows, required this.savedAt});

  Map<String, dynamic> toJson() => {
    'v': 1,
    'headers': headers,
    'rows': rows,
    'savedAt': savedAt.toIso8601String(),
  };

  static TableState? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      final headers = List<String>.from(json['headers'] ?? const <String>[]);
      final rowsDyn = json['rows'] as List<dynamic>? ?? const <dynamic>[];
      final rows = rowsDyn.map((e) => List<String>.from(e as List<dynamic>)).toList(growable: false);
      final savedAt = DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now();
      return TableState(headers: headers, rows: rows, savedAt: savedAt);
    } catch (_) {
      return null;
    }
  }
}

class LocalStore {
  LocalStore._();

  static Future<void> save(TableState state) async {
    try {
      final s = _sanitize(state);
      html.window.localStorage[_kStorageKey] = jsonEncode(s.toJson());
    } catch (_) {}
  }

  static TableState? load() {
    try {
      final raw = html.window.localStorage[_kStorageKey];
      if (raw == null || raw.isEmpty) return null;
      return TableState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static void clear() => html.window.localStorage.remove(_kStorageKey);

  static void downloadBackup(TableState state, {String filename = 'bitacora_backup.json'}) {
    try {
      final s = _sanitize(state);
      final bytes = utf8.encode(jsonEncode(s.toJson()));
      final blob = html.Blob([bytes], 'application/json;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final a = html.AnchorElement(href: url)..download = filename;
      a.click();
      html.Url.revokeObjectUrl(url);
    } catch (_) {}
  }

  static Future<TableState?> importBackup() async {
    final c = Completer<TableState?>();
    try {
      final input = html.FileUploadInputElement()
        ..accept = 'application/json'
        ..multiple = false;

      input.onChange.listen((_) {
        final file = input.files?.first;
        if (file == null) {
          if (!c.isCompleted) c.complete(null);
          return;
        }
        final reader = html.FileReader();
        reader.onLoadEnd.listen((_) {
          try {
            final text = reader.result?.toString() ?? '';
            final map = jsonDecode(text) as Map<String, dynamic>;
            final ts = TableState.fromJson(map);
            if (!c.isCompleted) c.complete(_sanitize(ts));
          } catch (_) {
            if (!c.isCompleted) c.complete(null);
          }
        });
        reader.readAsText(file);
      });

      input.click();
    } catch (_) {
      if (!c.isCompleted) c.complete(null);
    }
    return c.future;
  }
}

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

TableState _sanitize(TableState? s) {
  if (s == null) {
    return TableState(headers: const <String>[], rows: const <List<String>>[], savedAt: DateTime.now());
  }
  const int maxRows = 5000, maxCols = 32, maxCellLen = 2000;

  final headers = (s.headers.length > maxCols)
      ? s.headers.take(maxCols).toList(growable: false)
      : List<String>.from(s.headers, growable: false);

  List<List<String>> rows = s.rows;
  if (rows.length > maxRows) rows = rows.take(maxRows).toList(growable: false);
  rows = rows.map((r) {
    final t = (r.length > maxCols) ? r.take(maxCols).toList() : List<String>.from(r);
    for (var i = 0; i < t.length; i++) {
      final v = t[i];
      if (v.length > maxCellLen) t[i] = v.substring(0, maxCellLen);
    }
    return List<String>.from(t, growable: false);
  }).toList(growable: false);

  return TableState(headers: headers, rows: rows, savedAt: DateTime.now());
}
