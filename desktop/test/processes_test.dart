import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_system_care/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/processes.dart';
import 'package:material_system_care/localization.dart';

void main() {
  testWidgets(
    'isolated process entry performs no collection or settings read',
    (tester) async {
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(Engine.channel, (call) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(Engine.channel, null),
      );
      await tester.pumpWidget(
        const CareApp(startProcesses: true, isolatedCapture: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProcessesPage), findsOneWidget);
      expect(calls, isEmpty);
    },
  );

  testWidgets('close review preserves Cantonese wording', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CopyScope(
          preferences: const {'language': 'yue'},
          child: ProcessesPage(
            invoke: (method, params) async => {
              'records': [
                {
                  'pid': 42,
                  'name': 'Example',
                  'startedAt': '2026-10-10T00:00:00Z',
                  'canRequestClose': true,
                },
              ],
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('更新程序'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('要求關閉'));
    await tester.pumpAndSettle();
    expect(find.text('要求正常關閉？'), findsOneWidget);
    expect(find.text('Request graceful close?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final requested in [true, false]) {
    testWidgets('close consent and identity, requested $requested', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <(String, Map<String, dynamic>)>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ProcessesPage(
            invoke: (method, params) async {
              calls.add((method, params));
              if (method == 'processes.list')
                return {
                  'records': [
                    {
                      'pid': 42,
                      'name': 'Example',
                      'startedAt': '2026-10-10T00:00:00.0000000Z',
                      'canRequestClose': true,
                      'workingSetBytes': 1024,
                      'cpuTotalMilliseconds': 50,
                    },
                    {'pid': 4, 'name': 'Protected', 'canRequestClose': false},
                  ],
                };
              return requested
                  ? {
                      'pid': 42,
                      'requested': true,
                      'terminated': false,
                      'mode': 'CloseMainWindow',
                    }
                  : {
                      'pid': 42,
                      'requested': false,
                      'reason':
                          'No main window is available for graceful close.',
                    };
            },
          ),
        ),
      );
      expect(calls, isEmpty);
      await tester.tap(find.text('Refresh processes'));
      await tester.pumpAndSettle();
      final actions = find.widgetWithText(OutlinedButton, 'Request close');
      expect(tester.widget<OutlinedButton>(actions.last).onPressed, isNull);
      await tester.tap(actions.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls.length, 1);
      await tester.tap(actions.first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Request close'));
      await tester.pumpAndSettle();
      expect(calls.last.$1, 'processes.stop');
      expect(calls.last.$2, {
        'pid': 42,
        'startedAt': '2026-10-10T00:00:00.0000000Z',
        'confirmed': true,
      });
      expect(
        find.text(
          requested
              ? 'Close requested. Process exit is not confirmed. Refresh to observe current records.'
              : 'No close request was accepted. The process may still be running.',
        ),
        findsOneWidget,
      );
      expect(actions, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
