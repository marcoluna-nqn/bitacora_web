// lib/models/table_state.dart
// Estado inmutable con helpers: withHeaders, withAppendedRows, withCell, withNewEmptyRow.
// Serialización JSON compacta. Normaliza filas ante cambios de columnas.

import 'dart:collection' show UnmodifiableListView;
import 'dart:convert';

class TableState {
  static const int schemaVersion = 1;

  final List<String> headers;
  final List<List<String>> rows;
  final DateTime savedAt;

  // Constructor inmutable + normalización profunda.
  factory TableState({
    required List<String> headers,
    required List<List<String>> rows,
    required DateTime savedAt,
  }) {
    final h = UnmodifiableListView<String>(
      headers.map((e) => e.toString()).toList(growable: false),
    );

    final r = UnmodifiableListView<List<String>>(
      rows
          .map((row) => UnmodifiableListView<String>(
        row.map((e) => e.toString()).toList(growable: false),
      ))
          .toList(growable: false),
    );

    final t = savedAt.toUtc();
    final normalizedRows = _normalizeRows(h, r);
    return TableState._internal(h, normalizedRows, t);
  }

  const TableState._internal(this.headers, this.rows, this.savedAt);

  factory TableState.empty({int cols = 5, int rows = 3}) {
    final headers =
    UnmodifiableListView(List<String>.filled(cols, '', growable: false));
    final data = UnmodifiableListView<List<String>>(
      List.generate(
        rows,
            (_) => UnmodifiableListView(
          List<String>.filled(cols, '', growable: false),
        ),
        growable: false,
      ),
    );
    return TableState._internal(headers, data, DateTime.now().toUtc());
  }

  int get colCount => headers.length;
  int get rowCount => rows.length;

  // ------------------- Serialización -------------------
  Map<String, dynamic> toJson() => {
    'v': schemaVersion,
    'headers': headers,
    'rows': rows,
    'savedAt': savedAt.toIso8601String(),
  };

  String toJsonString({bool pretty = false}) {
    final obj = toJson();
    if (!pretty) return jsonEncode(obj);
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(obj);
  }

  static TableState? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      final rawHeaders = json['headers'];
      final headers = (rawHeaders is List ? rawHeaders : const [])
          .map((e) => e.toString())
          .toList(growable: false);

      final rawRows = json['rows'];
      final rows = (rawRows is List ? rawRows : const []).map((r) {
        final rr = (r is List ? r : const []);
        return rr.map((e) => e.toString()).toList(growable: false);
      }).toList(growable: false);

      final savedAtRaw = json['savedAt']?.toString() ?? '';
      final savedAt =
          DateTime.tryParse(savedAtRaw)?.toUtc() ?? DateTime.now().toUtc();

      return TableState(headers: headers, rows: rows, savedAt: savedAt);
    } catch (_) {
      return null;
    }
  }

  static TableState? fromJsonString(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final m = jsonDecode(s);
      return m is Map<String, dynamic> ? fromJson(m) : null;
    } catch (_) {
      return null;
    }
  }

  // ------------------- Helpers funcionales -------------------

  /// Reemplaza headers y re-normaliza filas a la nueva cantidad de columnas.
  TableState withHeaders(List<String> newHeaders) {
    final n = newHeaders.length;
    final adjustedRows =
    rows.map((src) => _normalizeRowToLen(src, n)).toList(growable: false);
    return TableState(
      headers: newHeaders,
      rows: adjustedRows,
      savedAt: DateTime.now().toUtc(),
    );
  }

  /// Agrega filas al final (normaliza cada fila al ancho actual).
  TableState withAppendedRows(List<List<String>> chunk) {
    if (chunk.isEmpty) {
      return copyWith(savedAt: DateTime.now().toUtc());
    }
    final normalizedChunk = chunk
        .map((r) => _normalizeRowToLen(r, colCount))
        .toList(growable: false);
    final merged = <List<String>>[
      ...rows.map((r) => List<String>.from(r)),
      ...normalizedChunk,
    ];
    return TableState(
      headers: headers,
      rows: merged,
      savedAt: DateTime.now().toUtc(),
    );
  }

  /// Actualiza una celda (row, col).
  TableState withCell(int row, int col, String value) {
    if (row < 0 || row >= rowCount || col < 0 || col >= colCount) {
      return copyWith(savedAt: DateTime.now().toUtc());
    }
    if (rows[row][col] == value) {
      return copyWith(savedAt: DateTime.now().toUtc());
    }
    final newRows =
    rows.map((r) => List<String>.from(r)).toList(growable: false);
    newRows[row][col] = value;
    return TableState(
      headers: headers,
      rows: newRows,
      savedAt: DateTime.now().toUtc(),
    );
  }

  /// Inserta una nueva fila vacía al final.
  TableState withNewEmptyRow() {
    final newRows = List<List<String>>.from(rows, growable: true)
      ..add(List<String>.filled(colCount, ''));
    return TableState(
      headers: headers,
      rows: newRows,
      savedAt: DateTime.now().toUtc(),
    );
  }

  /// Copia con cambios crudos (mantiene inmutabilidad y UTC).
  TableState copyWith({
    List<String>? headers,
    List<List<String>>? rows,
    DateTime? savedAt,
  }) {
    final newHeaders = headers ?? this.headers;
    final newRows = rows ?? this.rows;
    final newSaved = (savedAt ?? this.savedAt).toUtc();
    return TableState(headers: newHeaders, rows: newRows, savedAt: newSaved);
  }

  // ------------------- Utilidades -------------------
  List<List<String>> toMutableMatrix() =>
      rows.map((r) => List<String>.from(r)).toList(growable: true);

  bool get isAllEmpty {
    if (headers.any((h) => h.isNotEmpty)) return false;
    for (final r in rows) {
      if (r.any((c) => c.isNotEmpty)) return false;
    }
    return true;
  }

  TableState trim({bool headersToo = true, bool cells = true}) {
    final newHeaders = headersToo
        ? headers.map((h) => h.trim()).toList(growable: false)
        : headers;
    final newRows = cells
        ? rows
        .map((r) => r.map((c) => c.trim()).toList(growable: false))
        .toList(growable: false)
        : rows;
    return TableState(
      headers: newHeaders,
      rows: newRows,
      savedAt: DateTime.now().toUtc(),
    );
  }

  TableState pruneTrailingEmptyColumns() {
    int lastKeep = colCount - 1;
    for (; lastKeep >= 0; lastKeep--) {
      final headerEmpty = headers[lastKeep].isEmpty;
      final allEmpty = rows.every((r) => r[lastKeep].isEmpty);
      if (!(headerEmpty && allEmpty)) break;
    }
    final keep = lastKeep + 1;
    if (keep == colCount) return this;
    if (keep <= 0) {
      return TableState.empty(cols: 0, rows: rowCount);
    }
    final newHeaders = List<String>.from(headers.take(keep));
    final newRows =
    rows.map((r) => List<String>.from(r.take(keep))).toList(growable: false);
    return TableState(
      headers: newHeaders,
      rows: newRows,
      savedAt: DateTime.now().toUtc(),
    );
  }

  // ------------------- Igualdad / hash -------------------
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TableState) return false;

    if (headers.length != other.headers.length) return false;
    for (var i = 0; i < headers.length; i++) {
      if (headers[i] != other.headers[i]) return false;
    }

    if (rows.length != other.rows.length) return false;
    for (var r = 0; r < rows.length; r++) {
      final a = rows[r], b = other.rows[r];
      if (a.length != b.length) return false;
      for (var c = 0; c < a.length; c++) {
        if (a[c] != b[c]) return false;
      }
    }

    return savedAt.toIso8601String() == other.savedAt.toIso8601String();
  }

  @override
  int get hashCode {
    var h = 17;
    for (final e in headers) {
      h = _hashCombine(h, e.hashCode);
    }
    for (final row in rows) {
      var rh = 17;
      for (final e in row) {
        rh = _hashCombine(rh, e.hashCode);
      }
      h = _hashCombine(h, rh);
    }
    h = _hashCombine(h, savedAt.toIso8601String().hashCode);
    return _hashFinish(h);
  }

  // ------------------- Privados -------------------
  static List<List<String>> _normalizeRows(
      List<String> headers,
      List<List<String>> rows,
      ) {
    final n = headers.length;
    if (n == 0) {
      return UnmodifiableListView<List<String>>(
        rows
            .map((_) => UnmodifiableListView<String>(const <String>[]))
            .toList(growable: false),
      );
    }
    return UnmodifiableListView<List<String>>(
      rows
          .map(
            (src) => UnmodifiableListView<String>(_normalizeRowToLen(src, n)),
      )
          .toList(growable: false),
    );
  }

  static List<String> _normalizeRowToLen(List<String> src, int n) {
    if (src.length == n) {
      return List<String>.from(src, growable: false);
    }
    if (src.length < n) {
      final out = List<String>.from(src, growable: true)
        ..addAll(List.filled(n - src.length, ''));
      return List<String>.from(out, growable: false);
    }
    return List<String>.from(src.take(n), growable: false);
  }

  static int _hashCombine(int hash, int value) {
    hash = 0x1fffffff & (hash + value);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int _hashFinish(int hash) {
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}
