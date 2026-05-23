import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  VoidCallback configureDesktopHarness() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final isKnownGridOverflow = details.library == 'rendering library' &&
          details.exceptionAsString().contains('A RenderFlex overflowed');
      if (isKnownGridOverflow) return;
      previousOnError?.call(details);
    };
    return () {
      debugDefaultTargetPlatformOverride = null;
      FlutterError.onError = previousOnError;
    };
  }

  Future<dynamic> pumpDesktopEditor(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'live-cell-editing-feedback',
          initialHeaders: <String>['Texto', 'Fotos'],
          initialRows: <List<String>>[
            <String>['seed', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state(find.byType(EditorScreen)) as dynamic;
  }

  Future<dynamic> pumpDesktopEditorWithTwoDataColumns(
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(
          sheetId: 'live-cell-navigation-feedback',
          initialHeaders: <String>['Col 1', 'Col 2', 'Fotos'],
          initialRows: <List<String>>[
            <String>['seed', '', ''],
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state(find.byType(EditorScreen)) as dynamic;
  }

  Future<Finder> openCellEditor(WidgetTester tester, String visibleText) async {
    await tester.tap(find.text(visibleText).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));

    final editor = find.byKey(const ValueKey('desktop-cell-editor-field'));
    expect(editor, findsOneWidget);
    return editor;
  }

  testWidgets('desktop cell editor shows draft text while typing',
      (tester) async {
    final restoreHarness = configureDesktopHarness();
    try {
      final state = await pumpDesktopEditor(tester);

      final editor = await openCellEditor(tester, 'seed');

      await tester.enterText(editor, 'a');
      expect(state.debugDisplayedCellText(0, 0), 'a');

      await tester.enterText(editor, 'ab');
      expect(state.debugDisplayedCellText(0, 0), 'ab');

      await tester.enterText(editor, 'abc');
      expect(state.debugDisplayedCellText(0, 0), 'abc');

      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(state.debugCellText(0, 0), 'abc');

      final editorAfterCommit = await openCellEditor(tester, 'abc');

      await tester.enterText(editorAfterCommit, '');
      expect(state.debugDisplayedCellText(0, 0), '');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(state.debugCellText(0, 0), '');
    } finally {
      restoreHarness();
    }
  });

  testWidgets('desktop cell editor keeps first key during focus handoff',
      (tester) async {
    final restoreHarness = configureDesktopHarness();
    try {
      final state = await pumpDesktopEditor(tester);

      await tester.tap(find.text('seed').first);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA, character: 'A');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      final editor = find.byKey(const ValueKey('desktop-cell-editor-field'));
      expect(editor, findsOneWidget);
      expect(state.debugDisplayedCellText(0, 0), 'A');
      final field = tester.widget<TextField>(editor);
      expect(field.controller?.text, 'A');

      await tester.enterText(editor, 'ABC');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(state.debugCellText(0, 0), 'ABC');
    } finally {
      restoreHarness();
    }
  });

  testWidgets('bare evidence shortcuts do not steal printable cell input',
      (tester) async {
    final restoreHarness = configureDesktopHarness();
    try {
      final state = await pumpDesktopEditorWithTwoDataColumns(tester);

      await tester.tap(find.text('seed').first);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA, character: 'A');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB, character: 'B');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC, character: 'C');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
      await tester.pump();

      final editor = find.byKey(const ValueKey('desktop-cell-editor-field'));
      expect(editor, findsOneWidget);
      expect(state.debugDisplayedCellText(0, 0), 'ABC');
      expect(find.textContaining('Permiso de mic'), findsNothing);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(state.debugCellText(0, 0), 'ABC');
    } finally {
      restoreHarness();
    }
  });

  testWidgets('desktop cell editor enter navigation commits left and right',
      (tester) async {
    final restoreHarness = configureDesktopHarness();
    try {
      final state = await pumpDesktopEditorWithTwoDataColumns(tester);

      var editor = await openCellEditor(tester, 'seed');
      await tester.enterText(editor, 'ABC');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(state.debugCellText(0, 0), 'ABC');
      expect(state.debugSelectedCol, 1);

      editor = find.byKey(const ValueKey('desktop-cell-editor-field'));
      expect(editor, findsOneWidget);
      await tester.enterText(editor, 'DEF');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(state.debugCellText(0, 1), 'DEF');
      expect(state.debugSelectedCol, 0);
    } finally {
      restoreHarness();
    }
  });

  testWidgets('desktop cell editor tab navigation commits left and right',
      (tester) async {
    final restoreHarness = configureDesktopHarness();
    try {
      final state = await pumpDesktopEditorWithTwoDataColumns(tester);

      var editor = await openCellEditor(tester, 'seed');
      await tester.enterText(editor, 'TAB1');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(state.debugCellText(0, 0), 'TAB1');
      expect(state.debugSelectedCol, 1);

      editor = find.byKey(const ValueKey('desktop-cell-editor-field'));
      expect(editor, findsOneWidget);
      await tester.enterText(editor, 'TAB2');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(state.debugCellText(0, 1), 'TAB2');
      expect(state.debugSelectedCol, 0);
    } finally {
      restoreHarness();
    }
  });
}
