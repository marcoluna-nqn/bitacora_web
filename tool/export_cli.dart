import 'dart:io';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

void main() {
  final book = xlsio.Workbook(1);
  try {
    final ws = book.worksheets[0];
    ws.name = 'Test';
    final headers = ['Fecha', 'Progresiva', '1m Ω', '3m Ω', 'Obs'];
    for (int c = 0; c < headers.length; c++) {
      ws.getRangeByIndex(1, c + 1).setText(headers[c]);
    }
    final now = DateTime.now();
    final sample = [
      [now, 'PK-001', 12.34, 15.9, 'OK'],
      [now, 'PK-002', 10, 11.2, '—'],
    ];
    for (int r = 0; r < sample.length; r++) {
      for (int c = 0; c < headers.length; c++) {
        final cell = ws.getRangeByIndex(r + 2, c + 1);
        final v = sample[r][c];
        if (v is num) cell.setNumber(v.toDouble());
        else if (v is DateTime) { cell.dateTime = v; cell.numberFormat = 'dd/mm/yyyy'; }
        else cell.setText(v.toString());
      }
    }
    ws.getRangeByIndex(1, 1, sample.length + 1, headers.length)..autoFitColumns()..autoFitRows();

    final bytes = book.saveAsStream();
    final outDir = Directory('build')..createSync(recursive: true);
    final outPath = '${outDir.path}${Platform.pathSeparator}cli_export_test.xlsx';
    File(outPath).writeAsBytesSync(bytes, flush: true);
    stdout.writeln('OK -> ' + outPath);
  } finally {
    book.dispose();
  }
}
