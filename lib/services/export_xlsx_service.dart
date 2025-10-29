// lib/services/export_xlsx_service.dart
// En web usa export_xlsx_service_web.dart; en runtimes con dart:io usa export_xlsx_service_io.dart.
import 'export_xlsx_service_web.dart'
if (dart.library.io) 'export_xlsx_service_io.dart' as platform;

class ExportXlsxService {
  static Future<void> download({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    return platform.ExportXlsxPlatform.download(
      filename: filename,
      headers: headers,
      rows: rows,
    );
  }
}
