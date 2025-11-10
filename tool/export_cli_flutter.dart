import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

Future<Directory> _outDir() async {
  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (home != null) {
    final dl = Directory('$home${Platform.pathSeparator}Downloads');
    if (await dl.exists()) return dl;
  }
  return Directory('build')..createSync(recursive: true);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final book = xlsio.Workbook(1);
  try {
    final ws = book.worksheets[0];
    ws.name = 'Test';
    final headers = ['Fecha','Progresiva','1m Ω','3m Ω','Obs'];
    for (int c = 0; c < headers.length; c++) {
      ws.getRangeByIndex(1, c + 1).setText(headers[c]);
    }
    final now = DateTime.now();
    final data = [
      [now, 'PK-001', 12.34, 15.9, 'OK'],
      [now, 'PK-002', 10, 11.2, '—'],
    ];
    for (int r = 0; r < data.length; r++) {
      for (int c = 0; c < headers.length; c++) {
        final cell = ws.getRangeByIndex(r + 2, c + 1);
        final v = data[r][c];
        if (v is num) cell.setNumber(v.toDouble());
        else if (v is DateTime) { cell.dateTime = v; cell.numberFormat = 'dd/mm/yyyy'; }
        else cell.setText(v.toString());
      }
    }
    ws.getRangeByIndex(1,1, data.length+1, headers.length)
      ..autoFitColumns()
      ..autoFitRows();

    final bytes = book.saveAsStream();
    final out = await _outDir();
    final outPath = '${out.path}${Platform.pathSeparator}cli_export_test.xlsx';
    File(outPath).writeAsBytesSync(bytes, flush: true);
    // Print y salir
    // ignore: avoid_print
    print('OK -> $outPath');
  } finally {
    book.dispose();
  }
  exit(0);
}
