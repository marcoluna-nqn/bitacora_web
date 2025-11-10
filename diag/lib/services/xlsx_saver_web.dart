import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';

Future<String?> saveXlsx(String baseName, Uint8List bytes) async {
  await FileSaver.instance.saveFile(
    name: baseName,
    bytes: bytes,
    fileExtension: 'xlsx',
    mimeType: MimeType.microsoftExcel,
  );
  return null; // En web no hay ruta local real
}
