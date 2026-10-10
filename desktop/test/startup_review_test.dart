import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/main.dart';

void main() {
  test('only eligible current-user startup records expose changes', () {
    final row = <String, dynamic>{
      'id': 'Example',
      'enabled': true,
      'scope': 'user',
      'source': 'HKCU.Run',
      'canChange': true,
      'reviewRevision': 'A' * 64,
    };
    expect(canChangeStartupRecord(row), true);
    for (final change in <String, dynamic>{
      'id': '',
      'enabled': 'true',
      'scope': 'machine',
      'source': 'other',
      'canChange': false,
      'recoveryRequired': true,
      'reviewRevision': 'invalid',
    }.entries) {
      expect(
        canChangeStartupRecord({...row, change.key: change.value}),
        false,
        reason: change.key,
      );
    }
    expect(
      canChangeStartupRecord({
        ...row,
        'enabled': false,
        'source': 'originalStateJournal',
      }),
      true,
    );
    expect(canChangeStartupRecord({...row, 'id': 'bad\nname'}), false);
  });
  for (final enabled in [true, false]) {
    testWidgets(
      'startup review names effect and sends only selected state: $enabled',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final writes = <Map<dynamic, dynamic>>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(Engine.channel, (call) async {
          final method = call.arguments['method'];
          if (method == 'startup.list')
            return {
              'ok': true,
              'result': {
                'records': [
                  {
                    'id': 'Example',
                    'name': 'Example',
                    'enabled': enabled,
                    'scope': 'user',
                    'source': enabled ? 'HKCU.Run' : 'originalStateJournal',
                    'canChange': true,
                    'reviewRevision': 'A' * 64,
                    'command': 'private fixture command',
                    'extra': 'not forwarded',
                  },
                ],
              },
            };
          if (method == 'startup.set') {
            writes.add(Map.of(call.arguments['params']));
            return {
              'ok': true,
              'result': {'completed': true},
            };
          }
          throw StateError('Unexpected call');
        });
        addTearDown(
          () => messenger.setMockMethodCallHandler(Engine.channel, null),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: WorkflowPage(index: 3, title: 'Startup')),
          ),
        );
        await tester.pumpAndSettle();
        final action = enabled
            ? 'Disable selected startup entry'
            : 'Enable selected startup entry';
        await tester.tap(find.byTooltip('Record actions').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(find.textContaining('future sign-in behavior'), findsOneWidget);
        expect(writes, isEmpty);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(writes, isEmpty);
        await tester.tap(find.byTooltip('Record actions').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm selected action'));
        await tester.pumpAndSettle();
        expect(writes, [
          {
            'id': 'Example',
            'enabled': !enabled,
            'reviewRevision': 'A' * 64,
            'confirmed': true,
          },
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'a stale review refreshes records and requires new confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final revisions = <String>[];
      int reads = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(Engine.channel, (call) async {
        if (call.arguments['method'] == 'startup.list') {
          reads++;
          return {
            'ok': true,
            'result': {
              'records': [
                {
                  'id': 'Example',
                  'name': 'Example',
                  'enabled': true,
                  'scope': 'user',
                  'source': 'HKCU.Run',
                  'canChange': true,
                  'reviewRevision': (reads == 1 ? 'A' : 'B') * 64,
                },
              ],
            },
          };
        }
        revisions.add(call.arguments['params']['reviewRevision'] as String);
        return {
          'ok': false,
          'error': {
            'code': 'STARTUP_REVIEW_CHANGED',
            'message': 'Refresh and review again.',
          },
        };
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(Engine.channel, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WorkflowPage(index: 3, title: 'Startup')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Record actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disable selected startup entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm selected action'));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(revisions, ['A' * 64]);
      expect(
        find.textContaining('The startup record changed.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Record actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disable selected startup entry'));
      await tester.pumpAndSettle();
      expect(revisions.length, 1);
      await tester.tap(find.text('Confirm selected action'));
      await tester.pumpAndSettle();
      expect(revisions, ['A' * 64, 'B' * 64]);
      expect(tester.takeException(), isNull);
    },
  );
}
