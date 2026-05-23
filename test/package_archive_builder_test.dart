import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bitacora_web/services/package_archive_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String readArchiveText(Archive archive, String name) {
    final normalized = name.replaceAll('\\', '/');
    final file = archive.files.firstWhere(
      (f) => f.name.replaceAll('\\', '/') == normalized,
      orElse: () => throw StateError('Missing ZIP entry: $normalized'),
    );
    return utf8.decode(file.content as List<int>);
  }

  test('package archive includes every referenced asset path', () {
    const assetPath = 'attachments/files/A1_p1_sample_photo.png';
    final attachmentBytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    final manifest = <String, dynamic>{
      'assets': <Map<String, dynamic>>[
        <String, dynamic>{
          'path': assetPath,
          'fileName': 'sample_photo.png',
        },
      ],
    };

    final zipBytes = buildBitFlowPackageArchive(
      xlsxBytes: Uint8List.fromList(<int>[80, 75, 3, 4]),
      assets: <PackageArchiveAsset>[
        PackageArchiveAsset(path: assetPath, bytes: attachmentBytes),
      ],
      manifest: manifest,
      packageSheetJson: <String, dynamic>{'rows': <dynamic>[]},
    );
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final names =
        archive.files.map((f) => f.name.replaceAll('\\', '/')).toSet();

    expect(
        names,
        containsAll(<String>[
          'export.xlsx',
          'manifest.json',
          'sheet.json',
          assetPath,
        ]));

    final assetFile = archive.files.firstWhere(
      (f) => f.name.replaceAll('\\', '/') == assetPath,
    );
    expect(assetFile.content, attachmentBytes);

    final decodedManifest =
        jsonDecode(readArchiveText(archive, 'manifest.json'))
            as Map<String, dynamic>;
    final assets = (decodedManifest['assets'] as List<dynamic>)
        .cast<Map<dynamic, dynamic>>();
    expect(assets.single['path'], assetPath);
    expect(names, contains(assets.single['path']));
  });

  test('package archive blocks dangling asset references', () {
    Object? error;
    try {
      buildBitFlowPackageArchive(
        xlsxBytes: Uint8List.fromList(<int>[80, 75, 3, 4]),
        assets: const <PackageArchiveAsset>[
          PackageArchiveAsset(
            path: 'attachments/files/missing.png',
            bytes: null,
          ),
        ],
        manifest: <String, dynamic>{'assets': <dynamic>[]},
        packageSheetJson: <String, dynamic>{'rows': <dynamic>[]},
      );
    } catch (e) {
      error = e;
    }

    expect(error, isA<MissingPackageAssetException>());
    expect(error.toString(), contains('package_attachment_missing'));
    expect(error.toString(), contains('attachments/files/missing.png'));
  });
}
