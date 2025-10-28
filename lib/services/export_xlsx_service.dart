// lib/services/export_xlsx_service.dart
// Exportador XLSX para Flutter Web usando Syncfusion XlsIO 31.x
// Estilo limpio tipo Apple. Null‑safe. Sin TODOs.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;

class ExportXlsxService {
  const ExportXlsxService._();

  /// Genera y descarga un .xlsx en Web.
  static Future<void> download({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    // Workbook y hoja base
    final book = xls.Workbook();
    final sheet = book.worksheets[0];

    // Sanitizar dimensiones
    final colCount = _computeColCount(headers, rows);
    final data = _normalizeRows(rows, colCount);
    final saneHeaders = _normalizeHeaders(headers, colCount);

    // Escribir encabezados
    for (int c = 0; c < colCount; c++) {
      sheet.getRangeByIndex(1, c + 1).setText(saneHeaders[c]);
    }

    // Escribir datos
    for (int r = 0; r < data.length; r++) {
      final row = data[r];
      for (int c = 0; c < colCount; c++) {
        sheet.getRangeByIndex(r + 2, c + 1).setText(row[c]);
      }
    }

    // Estilos tipo Apple
    final header = book.styles.add('header');
    header.bold = true; // <- corregido: no usar fontBold
    header.hAlign = xls.HAlignType.center;
    header.vAlign = xls.VAlignType.center;
    header.backColor = '#F2F2F7'; // gris iOS
    header.fontColor = '#000000';
    header.borders.all.lineStyle = xls.LineStyle.thin;
    header.borders.all.color = '#D1D1D6';

    final body = book.styles.add('body');
    body.hAlign = xls.HAlignType.left;
    body.vAlign = xls.VAlignType.center;
    body.backColor = '#FFFFFF';
    body.fontColor = '#111111';
    body.borders.all.lineStyle = xls.LineStyle.thin;
    body.borders.all.color = '#E5E5EA';

    // Aplicar estilos por rango
    sheet.getRangeByIndex(1, 1, 1, colCount).cellStyle = header;
    if (data.isNotEmpty) {
      sheet.getRangeByIndex(2, 1, data.length + 1, colCount).cellStyle = body;
    }

    // Autoajustar ancho de columnas
    sheet.getRangeByIndex(1, 1, data.length + 1, colCount).autoFitColumns();

    // Crear binario y descargar
    final List<int> bytes = book.saveAsStream();
    book.dispose();

    final blob = html.Blob([Uint8List.fromList(bytes)],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final a = html.AnchorElement(href: url)..download = filename;
    a.click();
    html.Url.revokeObjectUrl(url);
  }

  static int _computeColCount(List<String> headers, List<List<String>> rows) {
    int maxCols = headers.length;
    for (final r in rows) {
      if (r.length > maxCols) maxCols = r.length;
    }
    return maxCols == 0 ? 1 : maxCols;
  }

  static List<String> _normalizeHeaders(List<String> headers, int len) {
    final out = List<String>.filled(len, '');
    for (int i = 0; i < len; i++) {
      final h = i < headers.length ? headers[i].trim() : '';
      out[i] = h.isEmpty ? 'Col ${i + 1}' : h;
    }
    return out;
  }

  static List<List<String>> _normalizeRows(List<List<String>> rows, int len) {
    return rows
        .map((r) {
      final tmp = List<String>.from(r);
      if (tmp.length < len) {
        tmp.addAll(List<String>.filled(len - tmp.length, ''));
      } else if (tmp.length > len) {
        tmp.removeRange(len, tmp.length);
      }
      return tmp;
    })
        .toList(growable: false);
  }
}
