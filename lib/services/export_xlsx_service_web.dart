// lib/services/export_xlsx_service_web.dart
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;

class ExportXlsxService {
  static Future<void> download({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final bytes = _buildXlsx(headers, rows);
    final name = filename.toLowerCase().endsWith('.xlsx') ? filename : '$filename.xlsx';

    final blob = html.Blob(
      [bytes],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);
    final a = html.AnchorElement(href: url)..download = name;
    a.click();
    html.Url.revokeObjectUrl(url);
  }

  static Uint8List _buildXlsx(List<String> headers, List<List<String>> rows) {
    final wb = xls.Workbook();
    final sheet = wb.worksheets[0];

    // Encabezados
    for (int c = 0; c < headers.length; c++) {
      sheet.getRangeByIndex(1, c + 1).setText(headers[c]);
    }

    // Filas
    for (int r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (int c = 0; c < headers.length; c++) {
        final v = (c < row.length) ? row[c] : '';
        sheet.getRangeByIndex(r + 2, c + 1).setText(v);
      }
    }

    final bytes = wb.saveAsStream();
    wb.dispose();
    return Uint8List.fromList(bytes);
  }
}
