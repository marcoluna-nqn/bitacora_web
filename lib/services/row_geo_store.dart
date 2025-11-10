// lib/services/row_geo_store.dart
import 'package:hive_flutter/hive_flutter.dart';

class RowGeo {
  final String sheetId;
  final int row;
  final double lat;
  final double lng;
  final double? accuracyM;
  final DateTime ts;

  const RowGeo({
    required this.sheetId,
    required this.row,
    required this.lat,
    required this.lng,
    required this.ts,
    this.accuracyM,
  });

  Map<String, dynamic> toMap() => {
    'sheetId': sheetId,
    'row': row,
    'lat': lat,
    'lng': lng,
    'acc': accuracyM,
    'ts': ts.toIso8601String(),
  };

  static RowGeo? from(Object? raw) {
    if (raw is! Map) return null;
    try {
      return RowGeo(
        sheetId: raw['sheetId'] as String,
        row: (raw['row'] as num).toInt(),
        lat: (raw['lat'] as num).toDouble(),
        lng: (raw['lng'] as num).toDouble(),
        accuracyM: (raw['acc'] as num?)?.toDouble(),
        ts: DateTime.tryParse(raw['ts'] as String? ?? '') ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}

class RowGeoStore {
  RowGeoStore._();
  static final RowGeoStore I = RowGeoStore._();
  static const _boxName = 'geo_box';
  Box<dynamic>? _box;

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.initFlutter();
      _box = await Hive.openBox<dynamic>(_boxName);
    } else {
      _box = Hive.box<dynamic>(_boxName);
    }
  }

  String _key(String sheetId, int row) => '$sheetId::$row';

  Future<void> save(RowGeo g) async {
    await init();
    await _box!.put(_key(g.sheetId, g.row), g.toMap());
  }

  Future<RowGeo?> get(String sheetId, int row) async {
    await init();
    return RowGeo.from(_box!.get(_key(sheetId, row)));
  }

  Future<void> clear(String sheetId, int row) async {
    await init();
    await _box!.delete(_key(sheetId, row));
  }

  Future<List<RowGeo>> listForSheet(String sheetId, int rows) async {
    await init();
    final out = <RowGeo>[];
    for (var r = 0; r < rows; r++) {
      final g = await get(sheetId, r);
      if (g != null) out.add(g);
    }
    return out;
  }
}
