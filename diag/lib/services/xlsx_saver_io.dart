import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String?> saveXlsx(String baseName, Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$baseName.xlsx';
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  return path;
}
