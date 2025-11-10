import 'xlsx_exporter.dart';

/// Fachada de compatibilidad para la exportación a XLSX.
/// Internamente delega en [XlsxExporter] pero mantiene la
/// misma firma usada históricamente en el proyecto.
///
/// Uso heredado:
///   ExportXlsxService.download(fileName: ..., headers: ..., rows: ...);
class ExportXlsxService {
  const ExportXlsxService._();

  /// Genera y guarda/descarga un XLSX.
  ///
  /// [fileName] tiene prioridad; si es nulo o vacío,
  /// se toma [name]. No se agrega la extensión, el
  /// exporter ya la maneja.
  static Future<void> download({
    String? fileName,
    String name = 'BitFlow',
    List<String> headers = const <String>[],
    List<List<String>> rows = const <List<String>>[],
  }) async {
    final base = _resolveBaseName(fileName, name);

    await XlsxExporter.export(
      headers: List<String>.from(headers),
      // Conversión explícita a List<List<dynamic>>.
      rows: rows.map((r) => List<dynamic>.from(r)).toList(),
      sheetName: 'Mediciones',
      baseFileName: base,
      autoFit: true,
    );
  }

  static String _resolveBaseName(String? fileName, String name) {
    final candidate =
    (fileName != null && fileName.trim().isNotEmpty) ? fileName : name;
    final trimmed = candidate.trim();
    return trimmed.isEmpty ? 'BitFlow' : trimmed;
  }
}
