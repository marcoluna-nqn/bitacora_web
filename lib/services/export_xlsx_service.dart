// Exporta XLSX real con Syncfusion XlsIO 31.x + FileSaver 0.3.x
import 'dart:typed_data';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:file_saver/file_saver.dart';

class ExportXlsxService {
  ExportXlsxService._();

  static Future<void> download({
    required String fileName,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final bytes = _buildWorkbookBytes(headers: headers, rows: rows);

    final baseName = fileName.endsWith('.xlsx')
        ? fileName.substring(0, fileName.length - 5)
        : fileName;

    await FileSaver.instance.saveFile(
      name: baseName,
      bytes: bytes,
      fileExtension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  static Uint8List _buildWorkbookBytes({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final book = xlsio.Workbook();
    final sh = book.worksheets[0];

    for (var c = 0; c < headers.length; c++) {
      final cell = sh.getRangeByIndex(1, c + 1);
      cell.setText(headers[c]);
      final st = cell.cellStyle;
      st.bold = true;
    }

    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (var c = 0; c < headers.length && c < row.length; c++) {
        sh.getRangeByIndex(r + 2, c + 1).setText(row[c]);
      }
    }

    for (var c = 1; c <= headers.length; c++) {
      sh.autoFitColumn(c);
    }

    final bytes = book.saveAsStream();
    book.dispose();
    return Uint8List.fromList(bytes);
  }
}
