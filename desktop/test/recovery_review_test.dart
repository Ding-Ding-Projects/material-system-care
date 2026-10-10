import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/main.dart';

void main() {
  for (final reduced in [true, false])
    for (final outcome in ['cancel', 'confirm', 'dispose']) {
      testWidgets(
        'minimum recovery modal paging reduced=$reduced outcome=$outcome',
        (tester) async {
          tester.view.physicalSize = const Size(800, 600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final methods = <String>[];
          final changes = <Map>[];
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            Engine.channel,
            (call) async {
              final args = call.arguments as Map;
              final method = args['method'] as String;
              methods.add(method);
              if (method == 'cleanup.history')
                return {
                  'ok': true,
                  'result': {
                    'receipts': [
                      {
                        'id': 'receipt-1',
                        'itemCount': 12,
                        'quarantined': 12,
                        'restored': 0,
                        'conflicts': 0,
                        'skipped': 0,
                      },
                    ],
                  },
                };
              if (method == 'cleanup.restore')
                changes.add(Map.from(args['params'] as Map));
              return {
                'ok': true,
                'result': {
                  'receiptId': 'receipt-1',
                  'recordedOnly': true,
                  'mutationPerformed': false,
                  'partial': false,
                  'cancelled': false,
                  'items': [
                    for (var i = 0; i < 12; i++)
                      {
                        'path': r'C:\fixture\review\' + 'file-$i.tmp',
                        'size': 1,
                        'state': method == 'cleanup.restore'
                            ? 'restored'
                            : 'quarantined',
                      },
                  ],
                },
              };
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(Engine.channel, null),
          );
          await tester.pumpWidget(
            CareApp(
              cleanupFixture: true,
              isolatedCapture: true,
              capturePreferences: {
                'language': 'both',
                'theme': 'dark',
                'textScale': 2.0,
                'reducedMotion': reduced,
              },
            ),
          );
          await tester.pumpAndSettle();
          Future<void> show(String label) async {
            if (find.byTooltip('Close').evaluate().isNotEmpty) {
              await tester.tap(find.byTooltip('Close'));
              await tester.pumpAndSettle();
            }
            await tester.scrollUntilVisible(
              find.textContaining(label),
              180,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.ensureVisible(find.textContaining(label));
            await tester.pumpAndSettle();
          }

          await show('Recovery history');
          await tester.tap(find.textContaining('Recovery history'));
          await tester.pumpAndSettle();
          await show('Review restoration');
          await tester.tap(find.textContaining('Review restoration'));
          await tester.pumpAndSettle();
          final dialog = find.byType(AlertDialog);
          final position = tester
              .state<ScrollableState>(
                find
                    .descendant(of: dialog, matching: find.byType(Scrollable))
                    .first,
              )
              .position;
          expect(position.maxScrollExtent, greaterThan(0));
          await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
          await tester.pump();
          if (!reduced) {
            await tester.pump(const Duration(milliseconds: 40));
            expect(position.pixels, greaterThan(0));
            expect(position.pixels, lessThan(position.viewportDimension * .8));
          }
          await tester.pumpAndSettle();
          expect(position.pixels, greaterThan(0));
          final cancel = find.descendant(
            of: dialog,
            matching: find.textContaining('Cancel'),
          );
          Focus.of(tester.element(cancel)).requestFocus();
          await tester.pump();
          final first = position.pixels;
          await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
          await tester.pumpAndSettle();
          expect(position.pixels, greaterThan(first));
          final second = position.pixels;
          await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
          await tester.pumpAndSettle();
          expect(position.pixels, lessThan(second));
          final editable = tester.widget<EditableText>(
            find
                .descendant(of: dialog, matching: find.byType(EditableText))
                .first,
          );
          editable.focusNode.requestFocus();
          await tester.pump();
          final before = position.pixels;
          await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
          await tester.pumpAndSettle();
          expect(position.pixels, before);
          if (outcome == 'dispose') {
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
            expect(changes, isEmpty);
          } else {
            await tester.tap(
              outcome == 'cancel'
                  ? cancel
                  : find.descendant(
                      of: dialog,
                      matching: find.textContaining('Confirm selected action'),
                    ),
            );
            await tester.pumpAndSettle();
            if (outcome == 'cancel') {
              expect(changes, isEmpty);
              expect(
                FocusManager.instance.primaryFocus?.debugLabel,
                isNot('Recovery review paging'),
              );
            } else {
              expect(changes.single, {
                'receiptId': 'receipt-1',
                'confirmed': true,
              });
            }
          }
          expect(methods.take(2), ['cleanup.history', 'cleanup.details']);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }

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
