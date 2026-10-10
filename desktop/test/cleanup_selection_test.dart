import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/main.dart';
import 'package:material_system_care/cleanup_workspace.dart';

void main() {
  testWidgets('cleanup applies only reviewed selected plan indexes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final mutations = <Map<dynamic, dynamic>>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(Engine.channel, (call) async {
      final method = call.arguments['method'];
      if (method == 'cleanup.apply')
        mutations.add(Map<dynamic, dynamic>.from(call.arguments['params']));
      return {
        'ok': true,
        'result': method == 'cleanup.scan'
            ? {
                'planId': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                'mutationPerformed': false,
                'fixture': true,
                'root': r'C:\fixture',
                'category': 'aged-user-temp-files',
                'minimumAgeDays': 7,
                'expiresUtc': DateTime.now()
                    .toUtc()
                    .add(const Duration(hours: 1))
                    .toIso8601String(),
                'totalBytes': 24,
                'inaccessible': 0,
                'reparseSkipped': 0,
                'unavailable': 0,
                'truncated': false,
                'targets': [
                  {'path': r'C:\fixture\keep.tmp', 'size': 12},
                  {'path': r'C:\fixture\chosen.tmp', 'size': 12},
                ],
              }
            : method == 'cleanup.apply'
            ? {
                'receiptId': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                'items': [
                  {
                    'target': {'path': r'C:\fixture\chosen.tmp', 'size': 12},
                    'state': 'quarantined',
                  },
                ],
                'partial': false,
                'cancelled': false,
                'plannedCount': 1,
                'permanentDeletion': false,
              }
            : {'records': <dynamic>[]},
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(Engine.channel, null));
    await tester.pumpWidget(
      MaterialApp(
        home: CleanupWorkspace(
          invoke: Engine.invoke,
          cancel: Engine.cancel,
          onRecovery: (_) {},
          fixture: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan recoverable cleanup'));
    await tester.pumpAndSettle();
    FilledButton applyButton() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Apply selected cleanup targets'),
    );
    expect(applyButton().onPressed, isNull);
    await tester.enterText(find.byType(SearchBar), 'chosen.tmp');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'chosen.tmp'));
    await tester.pumpAndSettle();
    expect(applyButton().onPressed, isNotNull);
    await tester.tap(find.text('Apply selected cleanup targets'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining(r'C:\fixture\chosen.tmp'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining(r'C:\fixture\keep.tmp'),
      ),
      findsNothing,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(mutations, isEmpty);
    await tester.tap(find.text('Apply selected cleanup targets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm selected action'));
    await tester.pumpAndSettle();
    expect(mutations, [
      {
        'planId': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'targetIndexes': [1],
        'confirmed': true,
      },
    ]);
    expect(tester.takeException(), isNull);
  });
}
