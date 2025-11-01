import 'dart:convert';
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
}
