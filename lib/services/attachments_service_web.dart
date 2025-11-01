// Adjunta archivos a una fila (Web). Guarda bytes en Hive.
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html show Blob, Url, AnchorElement, window;

class AttachmentRecord {
  final String id;
  final String sheetId;
  final int row;
  final String name;
  final String mime;
  final int size;
  final DateTime ts;
  final Uint8List bytes;

  const AttachmentRecord({
    required this.id,
    required this.sheetId,
    required this.row,
    required this.name,
    required this.mime,
    required this.size,
    required this.ts,
    required this.bytes,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'sheetId': sheetId,
    'row': row,
    'name': name,
    'mime': mime,
    'size': size,
    'ts': ts.toIso8601String(),
    'bytes': bytes,
  };

  static AttachmentRecord? from(Object? raw) {
    if (raw is! Map) return null;
    try {
      return AttachmentRecord(
        id: raw['id'] as String,
        sheetId: raw['sheetId'] as String,
        row: (raw['row'] as num).toInt(),
        name: raw['name'] as String,
        mime: raw['mime'] as String,
        size: (raw['size'] as num).toInt(),
        ts: DateTime.tryParse(raw['ts'] as String? ?? '') ?? DateTime.now(),
        bytes: (raw['bytes'] as Uint8List),
      );
    } catch (_) {
      return null;
    }
  }
}

class AttachmentsServiceWeb {
  AttachmentsServiceWeb._();
  static final AttachmentsServiceWeb I = AttachmentsServiceWeb._();

  static const String _boxName = 'att_box';
  Box<dynamic>? _box;

  Future<void> init() async {
    if (!kIsWeb) return;
    if (!Hive.isBoxOpen(_boxName)) {
      try {
        await Hive.initFlutter();
      } catch (_) {}
    }
    _box ??= await _openBoxSafe();
  }

  Future<Box<dynamic>> _openBoxSafe() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box<dynamic>(_boxName);
    return await Hive.openBox<dynamic>(_boxName);
  }

  bool get ready => _box != null;

  String _genId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final r = math.Random();
    final rand = List.generate(6, (_) => r.nextInt(36))
        .map((n) => 'abcdefghijklmnopqrstuvwxyz0123456789'[n])
        .join();
    return '$now-$rand';
  }

  Future<int> pickAndAdd({
    required String sheetId,
    required int row,
    List<XTypeGroup>? typeGroups,
  }) async {
    await init();
    final files = await openFiles(acceptedTypeGroups: typeGroups ?? const []);
    if (files.isEmpty) return 0;
    var count = 0;
    for (final xf in files) {
      final bytes = await xf.readAsBytes();
      final mime = xf.mimeType ?? 'application/octet-stream';
      await add(
        sheetId: sheetId,
        row: row,
        name: xf.name,
        mime: mime,
        bytes: bytes,
      );
      count++;
    }
    return count;
  }

  Future<String> add({
    required String sheetId,
    required int row,
    required String name,
    required String mime,
    required Uint8List bytes,
  }) async {
    await init();
    final id = _genId();
    final rec = AttachmentRecord(
      id: id,
      sheetId: sheetId,
      row: row,
      name: name,
      mime: mime,
      size: bytes.length,
      ts: DateTime.now(),
      bytes: bytes,
    );
    await _box!.put(id, rec.toMap());
    return id;
  }

  Future<List<AttachmentRecord>> listFor({
    required String sheetId,
    required int row,
  }) async {
    await init();
    final out = <AttachmentRecord>[];
    for (final v in _box!.values) {
      final rec = AttachmentRecord.from(v);
      if (rec == null) continue;
      if (rec.sheetId == sheetId && rec.row == row) out.add(rec);
    }
    out.sort((a, b) => b.ts.compareTo(a.ts));
    return out;
  }

  Future<void> delete(String id) async {
    await init();
    await _box!.delete(id);
  }

  Future<void> download(String id) async {
    await init();
    final raw = _box!.get(id);
    final rec = AttachmentRecord.from(raw);
    if (rec == null) return;
    if (kIsWeb) {
      final blob = html.Blob([rec.bytes], rec.mime);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final a = html.AnchorElement(href: url)..download = rec.name;
      a.click();
      html.Url.revokeObjectUrl(url);
    } else {
      final uri = Uri.dataFromBytes(rec.bytes, mimeType: rec.mime);
      await launchUrl(uri);
    }
  }

  Future<void> openInNewTab(String id) async {
    await init();
    final raw = _box!.get(id);
    final rec = AttachmentRecord.from(raw);
    if (rec == null) return;
    if (kIsWeb) {
      final blob = html.Blob([rec.bytes], rec.mime);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, '_blank');
    } else {
      final uri = Uri.dataFromBytes(rec.bytes, mimeType: rec.mime);
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }
}
