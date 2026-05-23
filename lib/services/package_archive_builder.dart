import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class PackageArchiveAsset {
  const PackageArchiveAsset({
    required this.path,
    required this.bytes,
  });

  final String path;
  final Uint8List? bytes;
}

class MissingPackageAssetException implements Exception {
  const MissingPackageAssetException(this.paths);

  final List<String> paths;

  String get message {
    final first = paths.isEmpty ? 'adjunto sin ruta' : paths.first;
    final extra = paths.length <= 1 ? '' : ' (+${paths.length - 1} mas)';
    return 'package_attachment_missing: $first$extra';
  }

  @override
  String toString() => message;
}

Uint8List buildBitFlowPackageArchive({
  required Uint8List xlsxBytes,
  required List<PackageArchiveAsset> assets,
  required Map<String, dynamic> manifest,
  required Map<String, dynamic> packageSheetJson,
}) {
  final missingPaths = <String>[];
  final archive = Archive();
  archive.addFile(ArchiveFile('export.xlsx', xlsxBytes.length, xlsxBytes));

  for (final asset in assets) {
    final normalizedPath = asset.path.trim().replaceAll('\\', '/');
    final bytes = asset.bytes;
    if (normalizedPath.isEmpty || bytes == null || bytes.isEmpty) {
      missingPaths
          .add(normalizedPath.isEmpty ? 'adjunto sin ruta' : normalizedPath);
      continue;
    }
    archive.addFile(ArchiveFile(normalizedPath, bytes.length, bytes));
  }

  if (missingPaths.isNotEmpty) {
    throw MissingPackageAssetException(List<String>.unmodifiable(missingPaths));
  }

  final manifestBytes = Uint8List.fromList(utf8.encode(jsonEncode(manifest)));
  archive.addFile(
    ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
  );

  final sheetJsonBytes = Uint8List.fromList(
    utf8.encode(jsonEncode(packageSheetJson)),
  );
  archive.addFile(
    ArchiveFile('sheet.json', sheetJsonBytes.length, sheetJsonBytes),
  );

  final zipData = ZipEncoder().encode(archive);
  return Uint8List.fromList(zipData);
}
