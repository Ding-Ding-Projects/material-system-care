import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/main.dart';

void main() {
  testWidgets(
    'restore reviews stored file details before explicit confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <String>[];
      var unavailable = false;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(Engine.channel, (call) async {
        final method = call.arguments['method'] as String;
        calls.add(method);
        if (method == 'cleanup.details' && unavailable)
          throw StateError('Recovery details unavailable');
        if (method == 'cleanup.details')
          return {
            'ok': true,
            'result': {
              'receiptId': 'receipt-1',
              'recordedOnly': true,
              'mutationPerformed': false,
              'items': [
                {
                  'path': r'C:\fixture\restorable.tmp',
                  'state': 'quarantined',
                  'size': 12,
                },
              ],
            },
          };
        if (method == 'cleanup.restore')
          expect(call.arguments['params'], {
            'receiptId': 'receipt-1',
            'confirmed': true,
          });
        return {
          'ok': true,
          'result': method == 'cleanup.restore'
              ? {
                  'receiptId': 'receipt-1',
                  'items': [
                    {
                      'path': r'C:\fixture\restorable.tmp',
                      'size': 12,
                      'state': 'restored',
                    },
                  ],
                  'partial': false,
                  'cancelled': false,
                }
              : {
                  'receipts': [
                    {'id': 'receipt-1', 'planId': 'plan-1'},
                  ],
                },
        };
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(Engine.channel, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WorkflowPage(index: 1, title: 'Storage')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recovery history'));
      await tester.pumpAndSettle();
      Future<void> review() async {
        await tester.tap(find.text('Review restoration'));
        await tester.pumpAndSettle();
      }

      await review();
      expect(calls, ['cleanup.history', 'cleanup.details']);
      expect(find.textContaining(r'C:\fixture\restorable.tmp'), findsOneWidget);
      expect(
        find.textContaining('Recorded state: In recovery storage'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls.contains('cleanup.restore'), isFalse);
      unavailable = true;
      await review();
      expect(find.byType(AlertDialog), findsNothing);
      expect(calls.contains('cleanup.restore'), isFalse);
      unavailable = false;
      await review();
      await tester.tap(find.text('Confirm selected action'));
      await tester.pumpAndSettle();
      expect(calls.where((method) => method == 'cleanup.restore').length, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
