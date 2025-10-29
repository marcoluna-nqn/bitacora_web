import 'dart:typed_data';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;
import 'export_xlsx_saver_stub.dart'
  if (dart.library.html) 'export_xlsx_saver_web.dart';

class ExportXlsxService {
  static Future<void> download({
    required String fileName,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final book = xls.Workbook();
    final sheet = book.worksheets[0];

    int colCount = headers.length;
    for (final r in rows) {
      if (r.length > colCount) colCount = r.length;
    }
    if (colCount == 0) colCount = 1;

    final saneHeaders = _normalizeHeaders(headers, colCount);
    final saneRows = _normalizeRows(rows, colCount);

    for (int c = 0; c < colCount; c++) {
      sheet.getRangeByIndex(1, c + 1).setText(saneHeaders[c]);
    }
    for (int r = 0; r < saneRows.length; r++) {
      for (int c = 0; c < colCount; c++) {
        sheet.getRangeByIndex(r + 2, c + 1).setText(saneRows[r][c]);
      }
    }

    final headerStyle = book.styles.add('header')
      ..bold = true
      ..hAlign = xls.HAlignType.center
      ..vAlign = xls.VAlignType.center
      ..backColor = '#F2F2F7'
      ..fontColor = '#000000';
    headerStyle.borders.all
      ..lineStyle = xls.LineStyle.thin
      ..color = '#D1D1D6';

    final bodyStyle = book.styles.add('body')
      ..hAlign = xls.HAlignType.left
      ..vAlign = xls.VAlignType.center
      ..backColor = '#FFFFFF'
      ..fontColor = '#111111';
    bodyStyle.borders.all
      ..lineStyle = xls.LineStyle.thin
      ..color = '#E5E5EA';

    sheet.getRangeByIndex(1, 1, 1, colCount).cellStyle = headerStyle;
    if (saneRows.isNotEmpty) {
      sheet.getRangeByIndex(2, 1, saneRows.length + 1, colCount).cellStyle = bodyStyle;
    }
    sheet.getRangeByIndex(1, 1, saneRows.length + 1, colCount).autoFitColumns();

    final bytes = Uint8List.fromList(book.saveAsStream());
    book.dispose();
    await saveXlsxBytes(bytes, fileName);
  }

  static List<String> _normalizeHeaders(List<String> headers, int len) {
    final out = List<String>.filled(len, '');
    for (int i = 0; i < len; i++) {
      final t = i < headers.length ? headers[i].trim() : '';
      out[i] = t.isEmpty ? 'Col ${i + 1}' : t;
    }
    return out;
  }

  static List<List<String>> _normalizeRows(List<List<String>> rows, int len) {
    return rows.map((r) {
      final t = List<String>.from(r);
      if (t.length < len) {
        t.addAll(List<String>.filled(len - t.length, ''));
      } else if (t.length > len) {
        t.removeRange(len, t.length);
      }
      return t;
    }).toList(growable: false);
  }
}
