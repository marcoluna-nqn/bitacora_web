import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String readArchiveText(Archive archive, String name) {
    final normalized = name.replaceAll('\\', '/');
    final file = archive.files.firstWhere(
      (f) => f.name.replaceAll('\\', '/') == normalized,
      orElse: () => throw StateError('Missing XLSX entry: $normalized'),
    );
    return utf8.decode(file.content as List<int>);
  }

  List<String> sharedStringValues(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files
        .map((f) => f.name.replaceAll('\\', '/'))
        .toList(growable: false);
    if (!names.contains('xl/sharedStrings.xml')) return const <String>[];
    final xml = readArchiveText(archive, 'xl/sharedStrings.xml');
    return RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true)
        .allMatches(xml)
        .map((m) => m.group(1) ?? '')
        .toList(growable: false);
  }

  testWidgets('XLSX export uses active cell and header drafts', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'export-active-drafts',
          initialHeaders: <String>['Fecha', 'Medicion', 'Fotos'],
          initialRows: <List<String>>[
            <String>['2026-05-02', '10', ''],
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final dynamic state = tester.state(find.byType(EditorScreen));
    state.debugSetHeaderDraft(1, 'Medicion final');
    state.debugSetCellDraft(0, 1, 'draft export value');

    final xlsx = await state.debugBuildXlsxBytesForTest() as Uint8List?;
    expect(xlsx, isNotNull);
    final strings = sharedStringValues(xlsx!);
    expect(strings, contains('Medicion final'));
    expect(strings, contains('draft export value'));
  });
}
