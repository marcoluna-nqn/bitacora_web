import 'dart:typed_data';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

// Import condicional: en web usa saver_web, en móvil/desktop usa saver_io.
import 'package:bitacora_web/services/xlsx_saver_io.dart'
if (dart.library.html) 'package:bitacora_web/services/xlsx_saver_web.dart' as saver;

class ExportResult {
  final String fileName;
  final String? path; // null en web
  final int bytesCount;
  const ExportResult({
    required this.fileName,
    required this.path,
    required this.bytesCount,
  });
}

final class XlsxExporter {
  XlsxExporter._();

  static Future<ExportResult> exportXlsx({
    required List<String> headers,
    required List<List<Object?>> rows,
    String sheetName = 'Hoja1',
    String fileNamePrefix = 'Gridnote_Export',
  }) async {
    final bytes = _buildWorkbookBytes(
      headers: headers,
      rows: rows,
      sheetName: sheetName,
    );
    final ts = _timestamp();
    final baseName = '${_sanitize(fileNamePrefix)}_$ts';
    final fileName = '$baseName.xlsx';

    final savedPath = await saver.saveXlsx(baseName, bytes);
    return ExportResult(fileName: fileName, path: savedPath, bytesCount: bytes.length);
  }

  // ---------------- internals ----------------

  static Uint8List _buildWorkbookBytes({
    required List<String> headers,
    required List<List<Object?>> rows,
    required String sheetName,
  }) {
    final book = xlsio.Workbook();
    try {
      final sh = book.worksheets[0];
      sh.name = _safeSheetName(sheetName);

      // Metadatos mínimos
      try {
        final p = book.builtInProperties;
        p.author = 'Gridnote';
        p.company = 'Gridnote';
        p.title = 'Exportación';
        p.subject = 'Planilla';
      } catch (_) {}

      // Encabezados
      for (var c = 0; c < headers.length; c++) {
        final cell = sh.getRangeByIndex(1, c + 1);
        cell.setText(headers[c]);
        final st = cell.cellStyle;
        st.bold = true;
        st.vAlign = xlsio.VAlignType.center;
        st.hAlign = xlsio.HAlignType.left;
      }

      // Datos
      final rCount = rows.length;
      final cCount = headers.length;

      for (var r = 0; r < rCount; r++) {
        final row = rows[r];
        for (var c = 0; c < cCount && c < row.length; c++) {
          final v = row[c];
          final cell = sh.getRangeByIndex(r + 2, c + 1);
          if (v == null) {
            cell.setText('');
          } else if (v is num) {
            cell.setNumber(v.toDouble());
          } else if (v is DateTime) {
            cell.setDateTime(v);
            try {
              cell.numberFormat = 'dd/MM/yyyy';
            } catch (_) {}
          } else {
            cell.setText(v.toString());
          }
        }
      }

      // Bordes + autofit
      final lastRow = rCount + 1;
      final lastCol = cCount;
      if (lastRow > 0 && lastCol > 0) {
        try {
          final used = sh.getRangeByIndex(1, 1, lastRow, lastCol);
          used.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        } catch (_) {}
      }
      for (var c = 1; c <= cCount; c++) {
        try {
          sh.autoFitColumn(c);
        } catch (_) {}
      }

      // Tabla
      try {
        sh.tableCollection.create('Datos', sh.getRangeByIndex(1, 1, lastRow, lastCol));
      } catch (_) {}

      final list = book.saveAsStream(); // List<int>
      return Uint8List.fromList(list);
    } finally {
      book.dispose();
    }
  }

  static String _timestamp() {
    final d = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}_${two(d.hour)}${two(d.minute)}${two(d.second)}';
  }

  static String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  static String _safeSheetName(String s) {
    var t = s.replaceAll(RegExp(r'[\\/\?\*\[\]]'), ' ').trim();
    if (t.isEmpty) t = 'Hoja1';
    if (t.length > 31) t = t.substring(0, 31);
    return t;
  }
}
