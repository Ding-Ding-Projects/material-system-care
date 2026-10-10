import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/main.dart';
import 'package:material_system_care/scheduled_tasks.dart';

void main() {
  testWidgets(
    'isolated scheduled-task entry reads no settings or host records',
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
        const CareApp(startScheduledTasks: true, isolatedCapture: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ScheduledTasksPage), findsOneWidget);
      expect(calls, isEmpty);
    },
  );
  testWidgets(
    'explicit bounded inventory filters loaded rows and clears failed refresh',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <(String, Map<String, dynamic>)>[];
      var fail = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ScheduledTasksPage(
            invoke: (method, parameters) async {
              calls.add((method, parameters));
              if (fail)
                throw StateError('TASK_QUERY_UNAVAILABLE: private detail');
              return {
                'records': [
                  {
                    'name': 'Example task',
                    'path': r'\Folder\',
                    'state': 'Ready',
                    'enabled': true,
                    'infoAvailable': true,
                    'lastRun': null,
                    'nextRun': '2026-10-10T09:30:00',
                    'lastResult': 267011,
                  },
                ],
                'truncated': true,
                'observedAt': '2026-10-10T00:00:00Z',
              };
            },
          ),
        ),
      );
      expect(calls, isEmpty);
      await tester.tap(find.text('Read scheduled tasks'));
      await tester.pumpAndSettle();
      expect(calls.single.$1, 'tasks.list');
      expect(calls.single.$2, {'limit': 200});
      expect(find.text('Example task'), findsOneWidget);
      expect(
        find.text(
          'The record limit was reached. Filtering searches only the loaded subset; increase the limit for a broader view.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Example task'));
      await tester.pumpAndSettle();
      expect(find.text('Last result code: 0x00041303'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'unmatched');
      await tester.pump();
      expect(find.text('Example task'), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      fail = true;
      await tester.tap(find.text('Read scheduled tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Example task'), findsNothing);
      expect(find.textContaining('private detail'), findsNothing);
      expect(
        find.text(
          'Scheduled-task inventory is unavailable for this account. No task was run or changed.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets('late task inventory completion after disposal is harmless', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(home: ScheduledTasksPage(invoke: (_, __) => pending.future)),
    );
    await tester.tap(find.text('Read scheduled tasks'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Read scheduled tasks'),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete({'records': [], 'truncated': false, 'observedAt': 'now'});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
