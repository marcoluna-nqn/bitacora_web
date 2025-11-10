import 'dart:typed_data';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:file_saver/file_saver.dart';

/// Exportación XLSX real con autoFit de columnas.
/// Compatible con llamadas antiguas: `fileName:`
/// y nuevas: `name:` (sin extensión).
class ExportXlsxService {
  static Future<void> download({
    String? fileName, // opcional para compatibilidad retro
    String name = 'Gridnote',
    List<String> headers = const [],
    List<List<String>> rows = const [],
  }) async {
    final book = xlsio.Workbook();
    try {
      final sh = book.worksheets[0];

      // Encabezados
      for (var c = 0; c < headers.length; c++) {
        final cell = sh.getRangeByIndex(1, c + 1);
        cell.setText(headers[c]);
        cell.cellStyle.bold = true;
      }

      // Filas
      for (var r = 0; r < rows.length; r++) {
        for (var c = 0; c < rows[r].length; c++) {
          sh.getRangeByIndex(r + 2, c + 1).setText(rows[r][c]);
        }
      }

      // Auto-ajuste de ancho
      final totalCols = headers.isEmpty ? (rows.isEmpty ? 0 : rows.map((e) => e.length).fold<int>(0, (a, b) => b > a ? b : a)) : headers.length;
      for (var c = 1; c <= totalCols; c++) {
        try { sh.autoFitColumn(c); } catch (_) {}
      }

      // Guardado
      final bytes = Uint8List.fromList(book.saveAsStream());
      final suggested = (fileName?.trim().isNotEmpty ?? false) ? fileName!.trim() : '$name.xlsx';
      final base = suggested.toLowerCase().endsWith('.xlsx')
          ? suggested.substring(0, suggested.length - 5)
          : suggested;

      await FileSaver.instance.saveFile(
        name: base,
        bytes: bytes,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    } finally {
      book.dispose();
    }
  }
}
