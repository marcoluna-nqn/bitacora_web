// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;

class ExportXlsxService {
  static Future<void> download({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final book = xls.Workbook();
    final sheet = book.worksheets[0];

    final colCount = _computeColCount(headers, rows);
    final data = _normalizeRows(rows, colCount);
    final saneHeaders = _normalizeHeaders(headers, colCount);

    for (int c=0;c<colCount;c++){ sheet.getRangeByIndex(1,c+1).setText(saneHeaders[c]); }
    for (int r=0;r<data.length;r++){
      for (int c=0;c<colCount;c++){ sheet.getRangeByIndex(r+2,c+1).setText(data[r][c]); }
    }

    final header = book.styles.add('header')
      ..bold = true
      ..hAlign = xls.HAlignType.center
      ..vAlign = xls.VAlignType.center
      ..backColor = '#F2F2F7'
      ..fontColor = '#000000';
    header.borders.all
      ..lineStyle = xls.LineStyle.thin
      ..color = '#D1D1D6';

    final body = book.styles.add('body')
      ..hAlign = xls.HAlignType.left
      ..vAlign = xls.VAlignType.center
      ..backColor = '#FFFFFF'
      ..fontColor = '#111111';
    body.borders.all
      ..lineStyle = xls.LineStyle.thin
      ..color = '#E5E5EA';

    sheet.getRangeByIndex(1,1,1,colCount).cellStyle = header;
    if (data.isNotEmpty) sheet.getRangeByIndex(2,1,data.length+1,colCount).cellStyle = body;
    sheet.getRangeByIndex(1,1,data.length+1,colCount).autoFitColumns();

    final bytes = Uint8List.fromList(book.saveAsStream());
    book.dispose();

    final blob = html.Blob([bytes],'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href:url)..download=filename..click();
    html.Url.revokeObjectUrl(url);
  }

  static int _computeColCount(List<String> h, List<List<String>> r){
    int m=h.length; for(final x in r){ if(x.length>m) m=x.length; } return m==0?1:m;
  }
  static List<String> _normalizeHeaders(List<String> h,int len){
    final out=List<String>.filled(len,''); for(int i=0;i<len;i++){ final t=i<h.length?h[i].trim():''; out[i]=t.isEmpty?'Col ${i+1}':t; } return out;
  }
  static List<List<String>> _normalizeRows(List<List<String>> rows,int len){
    return rows.map((r){ final t=List<String>.from(r);
      if(t.length<len) t.addAll(List<String>.filled(len-t.length,''));
      if(t.length>len) t.removeRange(len,t.length); return t;
    }).toList(growable:false);
  }
}
