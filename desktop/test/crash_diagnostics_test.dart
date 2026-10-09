import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/crash_diagnostics.dart';

void main() {
  for (final scenario in <(Object, String)>[
    (
      StateError('OPERATION_TIMEOUT: timed out'),
      'Crash collection exceeded fifteen seconds. Try a shorter period.',
    ),
    (MissingPluginException(), 'The local engine connection is unavailable.'),
  ]) {
    testWidgets('diagnostic reason: ${scenario.$2}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CrashDiagnosticsPage(
            invoke: (_, __) async => throw scenario.$1,
          ),
        ),
      );
      await tester.tap(find.text('Read crash evidence'));
      await tester.pumpAndSettle();
      expect(find.text(scenario.$2), findsOneWidget);
      expect(find.text('No matching events in this period.'), findsNothing);
    });
  }
  testWidgets('partial inventory and dump warnings remain explicit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CrashDiagnosticsPage(
          invoke: (_, __) async => {
            'events': <dynamic>[],
            'eventsTruncated': true,
            'dumps': <dynamic>[],
            'warnings': [
              'Dump metadata is unavailable for this account. No elevation was requested.',
            ],
          },
        ),
      ),
    );
    await tester.tap(find.text('Read crash evidence'));
    await tester.pumpAndSettle();
    expect(find.textContaining('newest 50'), findsOneWidget);
    expect(find.textContaining('No elevation was requested'), findsOneWidget);
  });
  testWidgets(
    'collection is explicit and a failed refresh removes stale evidence',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CrashDiagnosticsPage(
            invoke: (method, params) async {
              calls++;
              expect(method, 'diagnostics.crashes');
              expect(params, {'days': 30, 'limit': 50});
              if (calls > 1)
                throw StateError('EVENT_LOG_UNAVAILABLE: Access unavailable');
              return {
                'events': <dynamic>[],
                'dumps': <dynamic>[],
                'warnings': <dynamic>[],
              };
            },
          ),
        ),
      );
      expect(calls, 0);
      await tester.tap(find.text('Read crash evidence'));
      await tester.pumpAndSettle();
      expect(find.text('No matching events in this period.'), findsOneWidget);
      expect(find.textContaining('does not rule out a crash'), findsOneWidget);
      await tester.tap(find.text('Read crash evidence'));
      await tester.pumpAndSettle();
      expect(find.text('No matching events in this period.'), findsNothing);
      expect(
        find.textContaining('No permissions were changed'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'lookup does not collect events and safely completes after navigation away',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      await tester.pumpWidget(
        MaterialApp(
          home: CrashDiagnosticsPage(
            invoke: (method, params) {
              expect(method, 'diagnostics.explainStopCode');
              expect(params['code'], '0x9f');
              return pending.future;
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '0x9f');
      await tester.tap(find.text('Explain stop code'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
        isNull,
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      pending.complete({
        'hex': '0x0000009F',
        'name': 'DRIVER_POWER_STATE_FAILURE',
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
