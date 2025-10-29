import 'dart:typed_data';
import 'dart:io' as io;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as pp;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

class ExportXlsxPlatform {
  static Future<void> download({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final book = xls.Workbook();
    final sheet = book.worksheets[0];

    final colCount = _colCount(headers, rows);
    final saneHeaders = _headers(headers, colCount);
    final data = _rows(rows, colCount);

    for (int c = 0; c < colCount; c++) {
      sheet.getRangeByIndex(1, c + 1).setText(saneHeaders[c]);
    }
    for (int r = 0; r < data.length; r++) {
      for (int c = 0; c < colCount; c++) {
        sheet.getRangeByIndex(r + 2, c + 1).setText(data[r][c]);
      }
    }

    final header = book.styles.add('hdr')
      ..bold = true
      ..hAlign = xls.HAlignType.center
      ..vAlign = xls.VAlignType.center;
    header.borders.all.lineStyle = xls.LineStyle.thin;

    final body = book.styles.add('body')
      ..hAlign = xls.HAlignType.left
      ..vAlign = xls.VAlignType.center;
    body.borders.all.lineStyle = xls.LineStyle.thin;

    sheet.getRangeByIndex(1, 1, 1, colCount).cellStyle = header;
    if (data.isNotEmpty) {
      sheet.getRangeByIndex(2, 1, data.length + 1, colCount).cellStyle = body;
    }
    for (var c = 1; c <= colCount; c++) {
      sheet.autoFitColumn(c);
    }

    final bytes = Uint8List.fromList(book.saveAsStream());
    book.dispose();

    final dir = await pp.getTemporaryDirectory();
    final path = p.join(dir.path, filename);
    final file = io.File(path);
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles([XFile(file.path)], text: 'Bitácora');
  }

  static int _colCount(List<String> h, List<List<String>> r) {
    var m = h.length;
    for (final x in r) {
      if (x.length > m) m = x.length;
    }
    return m == 0 ? 1 : m;
  }

  static List<String> _headers(List<String> h, int len) {
    final out = List<String>.filled(len, '');
    for (int i = 0; i < len; i++) {
      final t = i < h.length ? h[i].trim() : '';
      out[i] = t.isEmpty ? 'Col ${i + 1}' : t;
    }
    return out;
  }

  static List<List<String>> _rows(List<List<String>> rows, int len) {
    return rows.map((r) {
      final t = List<String>.from(r);
      if (t.length < len) t.addAll(List<String>.filled(len - t.length, ''));
      if (t.length > len) t.removeRange(len, t.length);
      return t;
    }).toList(growable: false);
  }
}
