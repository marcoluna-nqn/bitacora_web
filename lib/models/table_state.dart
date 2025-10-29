import 'dart:convert';

class TableState {
  static const int schemaVersion = 1;

  final List<String> headers;
  final List<List<String>> rows;
  final DateTime savedAt;

  const TableState({
    required this.headers,
    required this.rows,
    required this.savedAt,
  });

  int get colCount => headers.length;
  int get rowCount => rows.length;

  TableState normalized() {
    final n = colCount;
    final norm = List<List<String>>.generate(rows.length, (r) {
      final src = rows[r];
      if (src.length == n) return List<String>.from(src);
      if (src.length < n) {
        return List<String>.from(src)..addAll(List.filled(n - src.length, ''));
      }
      return List<String>.from(src.take(n));
    }, growable: false);
    return TableState(headers: List<String>.from(headers), rows: norm, savedAt: savedAt);
  }

  TableState copyWith({
    List<String>? headers,
    List<List<String>>? rows,
    DateTime? savedAt,
  }) =>
      TableState(
        headers: headers ?? this.headers,
        rows: rows ?? this.rows,
        savedAt: savedAt ?? this.savedAt,
      );

  Map<String, dynamic> toJson() => {
    'v': schemaVersion,
    'headers': headers,
    'rows': rows,
    'savedAt': savedAt.toIso8601String(),
  };

  static TableState? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    try {
      final headers =
      (json['headers'] as List? ?? const []).map((e) => e.toString()).toList(growable: false);
      final rows = (json['rows'] as List? ?? const [])
          .map((r) => (r as List).map((e) => e.toString()).toList(growable: false))
          .toList(growable: false);
      final savedAt = DateTime.tryParse(json['savedAt']?.toString() ?? '') ?? DateTime.now();
      return TableState(headers: headers, rows: rows, savedAt: savedAt).normalized();
    } catch (_) {
      return null;
    }
  }

  static TableState? fromJsonString(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static TableState empty({int cols = 5, int rows = 3}) => TableState(
    headers: List<String>.filled(cols, ''),
    rows: List<List<String>>.generate(rows, (_) => List<String>.filled(cols, '')),
    savedAt: DateTime.now(),
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TableState) return false;
    if (headers.length != other.headers.length || rows.length != other.rows.length) return false;
    for (int i = 0; i < headers.length; i++) {
      if (headers[i] != other.headers[i]) return false;
    }
    for (int r = 0; r < rows.length; r++) {
      final a = rows[r], b = other.rows[r];
      if (a.length != b.length) return false;
      for (int c = 0; c < a.length; c++) {
        if (a[c] != b[c]) return false;
      }
    }
    return savedAt.toIso8601String() == other.savedAt.toIso8601String();
  }

  @override
  int get hashCode {
    var h = headers.fold<int>(0, (p, e) => p ^ e.hashCode);
    for (final r in rows) {
      h ^= r.fold<int>(0, (p, e) => p ^ e.hashCode);
    }
    h ^= savedAt.toIso8601String().hashCode;
    return h;
  }
}
