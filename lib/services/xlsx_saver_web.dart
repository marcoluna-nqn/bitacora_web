import 'dart:typed_data';
import 'dart:html' as html;

/// Web: descarga directa de XLSX.
Future<String?> saveXlsx(String baseName, Uint8List bytes) async {
  final safe = _sanitize(baseName);
  final fileName = '$safe.xlsx';

  final blob = html.Blob(
    [bytes],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );

  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);

  // En Web devolvemos solo el nombre lógico.
  return fileName;
}

String _sanitize(String s) {
  final t = s.trim().replaceAll(RegExp(r'\.xlsx$', caseSensitive: false), '');
  return t.isEmpty ? 'bitflow_export' : t;
}
