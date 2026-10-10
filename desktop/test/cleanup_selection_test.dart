import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/main.dart';

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
                'planId': 'fixture-plan',
                'mutationPerformed': false,
                'targets': [
                  {'path': r'C:\fixture\keep.tmp'},
                  {'path': r'C:\fixture\chosen.tmp'},
                ],
              }
            : method == 'cleanup.apply'
            ? {
                'receiptId': 'fixture-plan',
                'items': [
                  {
                    'target': {'path': r'C:\fixture\chosen.tmp', 'size': 12},
                    'state': 'quarantined',
                  },
                ],
                'partial': false,
                'cancelled': false,
                'plannedCount': 1,
              }
            : {'records': <dynamic>[]},
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(Engine.channel, null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WorkflowPage(index: 0, title: 'Overview')),
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
        'planId': 'fixture-plan',
        'targetIndexes': [1],
        'confirmed': true,
      },
    ]);
    expect(tester.takeException(), isNull);
  });
}
