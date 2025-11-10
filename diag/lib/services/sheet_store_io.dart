import 'dart:convert';
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

  /// Guarda estado y garantiza presencia en el índice.
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
          'Fecha', 'Progresiva', '1 m (Ω)', '3 m (Ω)', '5 m (Ω)', 'Observaciones',
        ]);
      case TemplateKind.inventario:
        return _createWith(headers: const [
          'Item', 'Cantidad', 'Unidad', 'Ubicación', 'Nota',
        ]);
      case TemplateKind.checklist:
        return _createWith(headers: const [
          'Tarea', 'Responsable', 'Estado', 'Hora', 'Comentario',
        ]);
    }
  }

  /// Elimina hoja y la saca del índice (también el título).
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
}
