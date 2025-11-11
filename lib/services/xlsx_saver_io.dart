import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// IO (Android, iOS, desktop): guarda el XLSX en disco y devuelve la ruta.
Future<String?> saveXlsx(String baseName, Uint8List bytes) async {
  final safe = _sanitize(baseName);
  final fileName = '$safe.xlsx';

  final dir = await _resolveBaseDir();
  final file = File(p.join(dir.path, fileName));

  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<Directory> _resolveBaseDir() async {
  if (Platform.isAndroid || Platform.isIOS) {
    // Carpeta de documentos de la app. Desde ahí se comparte / envía por correo.
    return getApplicationDocumentsDirectory();
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;
    return getApplicationDocumentsDirectory();
  }

  return getApplicationDocumentsDirectory();
}

String _sanitize(String s) {
  final t = s.trim().replaceAll(RegExp(r'\.xlsx\$', caseSensitive: false), '');
  return t.isEmpty ? 'bitflow_export' : t;
}
