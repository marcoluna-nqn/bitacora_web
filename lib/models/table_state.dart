class TableState {
  final List<String> headers;
  final List<List<String>> rows;
  final DateTime savedAt;
  const TableState({required this.headers, required this.rows, required this.savedAt});
  Map<String, dynamic> toJson() => {
    'v': 1, 'headers': headers, 'rows': rows, 'savedAt': savedAt.toIso8601String()
  };
  static TableState? fromJson(Map<String, dynamic>? json){
    if(json==null) return null;
    try{
      final headers = List<String>.from(json['headers'] ?? const <String>[]);
      final rowsDyn = json['rows'] as List<dynamic>? ?? const <dynamic>[];
      final rows = rowsDyn.map((e)=>List<String>.from(e as List<dynamic>)).toList(growable:false);
      final savedAt = DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now();
      return TableState(headers: headers, rows: rows, savedAt: savedAt);
    }catch(_){ return null; }
  }
}
