import 'dart:io';
import 'package:flutter/material.dart';
import 'services/xlsx_exporter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final headers = ['Fecha','Progresiva','1m Ω','3m Ω','Obs'];
  final now = DateTime.now();
  final rows = [
    [now, 'PK-001', 12.34, 15.9, 'OK'],
    [now, 'PK-002', 10, 11.2, '—'],
  ];

  final res = await XlsxExporter.export(headers: headers, rows: rows, sheetName: 'Test');
  // Imprime a la terminal la ruta/URI
  // En Web se imprime el nombre y se descarga.
  // En móviles/escritorio, FileSaver devuelve path/URI según plataforma.
  // Cierra el proceso si es escritorio.
  // ignore: avoid_print
  print('XLSX -> ' + (res.savedPathOrUri ?? res.fileName));
  if (!Platform.isAndroid && !Platform.isIOS) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    exit(0);
  }

  runApp(const SizedBox.shrink()); // No muestra UI en móviles.
}
