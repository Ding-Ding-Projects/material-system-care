import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/cleanup.dart';
import 'package:material_system_care/localization.dart';
import 'package:material_system_care/main.dart';

void main() {
  test('method-required flags cannot be omitted or contradicted', () {
    final cases = <String, Map<String, dynamic>>{
      'cleanup.scan': {
        'planId': 'plan-1',
        'targets': [],
        'fixture': false,
        'truncated': false,
        'mutationPerformed': false,
      },
      'cleanup.apply': {
        'receiptId': 'receipt-1',
        'items': [],
        'partial': false,
        'cancelled': false,
        'permanentDeletion': false,
      },
      'cleanup.restore': {
        'receiptId': 'receipt-1',
        'items': [],
        'partial': false,
        'cancelled': false,
      },
      'cleanup.details': {
        'receiptId': 'receipt-1',
        'items': [],
        'recordedOnly': true,
        'mutationPerformed': false,
      },
    };
    for (final entry in cases.entries) {
      expect(
        () => CleanupResult.parse(entry.key, entry.value),
        returnsNormally,
      );
      for (final field in entry.value.keys.where(
        (key) => entry.value[key] is bool,
      )) {
        final missing = Map<String, dynamic>.of(entry.value)..remove(field);
        expect(
          () => CleanupResult.parse(entry.key, missing),
          throwsFormatException,
          reason: '${entry.key} requires $field',
        );
      }
    }
    expect(
      () => CleanupResult.parse('cleanup.history', {'receipts': []}),
      returnsNormally,
    );
    expect(
      () => CleanupResult.parse('cleanup.scan', {
        ...cases['cleanup.scan']!,
        'mutationPerformed': true,
      }),
      throwsFormatException,
    );
    expect(
      () => CleanupResult.parse('cleanup.apply', {
        ...cases['cleanup.apply']!,
        'permanentDeletion': true,
      }),
      throwsFormatException,
    );
    expect(
      () => CleanupResult.parse('cleanup.details', {
        ...cases['cleanup.details']!,
        'recordedOnly': false,
      }),
      throwsFormatException,
    );
  });

  testWidgets(
    'extra unrelated rows cannot escape typed cleanup search bounds',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        Engine.channel,
        (call) async => {
          'ok': true,
          'result': {
            'planId': 'plan-1',
            'fixture': true,
            'truncated': false,
            'mutationPerformed': false,
            'targets': [
              {'path': r'C:\fixture\only.tmp'},
            ],
            'items': [
              {'path': 'wrong-a'},
              {'path': 'wrong-b'},
              {'path': 'wrong-c'},
            ],
          },
        },
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(Engine.channel, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WorkflowPage(index: 1, title: 'Storage')),
        ),
      );
      await tester.tap(find.text('Scan recoverable cleanup'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(SearchBar), 'only');
      await tester.pumpAndSettle();
      expect(find.text('only.tmp'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('cleanup status flags reject non-booleans', () {
    for (final field in [
      'partial',
      'cancelled',
      'truncated',
      'fixture',
      'mutationPerformed',
      'permanentDeletion',
      'recordedOnly',
    ]) {
      for (final value in ['true', 1, null]) {
        expect(
          () => CleanupResult.parse('cleanup.apply', {
            'receiptId': 'receipt-1',
            'items': [],
            'partial': false,
            'cancelled': false,
            'permanentDeletion': false,
            field: value,
          }),
          throwsFormatException,
          reason: '$field=$value',
        );
      }
    }
  });

  testWidgets('mixed arrays cannot replace the typed plan in confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      Engine.channel,
      (call) async => {
        'ok': true,
        'result': {
          'planId': 'plan-1',
          'mutationPerformed': false,
          'fixture': true,
          'truncated': false,
          'targets': [
            {'path': r'C:\fixture\first.tmp'},
            {'path': r'C:\fixture\second.tmp'},
          ],
          'items': [
            {'path': r'C:\unrelated\wrong-first.tmp'},
            {'path': r'C:\unrelated\wrong-second.tmp'},
          ],
        },
      },
    );
    addTearDown(() => messenger.setMockMethodCallHandler(Engine.channel, null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WorkflowPage(index: 1, title: 'Storage')),
      ),
    );
    await tester.tap(find.text('Scan recoverable cleanup'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'second.tmp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply selected cleanup targets'));
    await tester.pumpAndSettle();
    expect(find.textContaining(r'C:\fixture\second.tmp'), findsOneWidget);
    expect(find.textContaining(r'C:\unrelated\wrong-second.tmp'), findsNothing);
  });

  testWidgets('cleanup file selection is reachable from the keyboard', (
    tester,
  ) async {
    final selected = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CleanupResults(
            result: CleanupResult.parse('cleanup.scan', {
              'planId': 'plan-1',
              'fixture': true,
              'truncated': false,
              'mutationPerformed': false,
              'targets': [
                {'path': r'C:\fixture\keyboard.tmp', 'size': 1},
              ],
            }),
            visibleIndexes: {0},
            selected: {},
            busy: false,
            onSelect: (i, _) => selected.add(i),
            onRestore: (_) {},
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(selected, [0]);
  });
  test(
    'typed results preserve original positions and reject malformed paths',
    () {
      final result = CleanupResult.parse('cleanup.scan', {
        'planId': 'plan-1',
        'fixture': true,
        'truncated': false,
        'mutationPerformed': false,
        'targets': [
          {'path': r'C:\fixture\first.tmp', 'size': 5},
          {'path': r'C:\fixture\second.tmp', 'size': 7},
        ],
      });
      expect(result.files[1].index, 1);
      expect(result.files[1].name, 'second.tmp');
      expect(
        () => CleanupResult.parse('cleanup.apply', {
          'receiptId': 'receipt-1',
          'partial': false,
          'cancelled': false,
          'permanentDeletion': false,
          'items': [
            {
              'target': {'hash': 'private'},
            },
          ],
        }),
        throwsFormatException,
      );
    },
  );

  testWidgets(
    'filtered selection uses original index and hides internal fields',
    (tester) async {
      final selected = <int>[];
      final result = CleanupResult.parse('cleanup.scan', {
        'planId': 'plan-1',
        'fixture': true,
        'truncated': false,
        'mutationPerformed': false,
        'targets': [
          {'path': r'C:\fixture\first.tmp', 'size': 5},
          {
            'path': r'C:\fixture\second.tmp',
            'size': 7,
            'hash': 'internal-secret',
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CleanupResults(
              result: result,
              visibleIndexes: {1},
              selected: {},
              busy: false,
              onSelect: (i, _) => selected.add(i),
              onRestore: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('first.tmp'), findsNothing);
      expect(find.text('second.tmp'), findsOneWidget);
      expect(find.textContaining('internal-secret'), findsNothing);
      expect(find.text(r'C:\fixture\second.tmp'), findsNothing);
      await tester.tap(find.text('second.tmp'));
      expect(selected, [1]);
      await tester.tap(find.text('File details'));
      await tester.pumpAndSettle();
      expect(find.text(r'C:\fixture\second.tmp'), findsOneWidget);
    },
  );

  testWidgets(
    'bilingual long-path partial and cancelled results fit minimum area',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final path =
          'C:\\fixture\\${List.filled(25, 'long-directory-name').join('\\')}\\file.tmp';
      final result = CleanupResult.parse('cleanup.apply', {
        'receiptId': 'receipt-1',
        'partial': true,
        'cancelled': true,
        'plannedCount': 2,
        'permanentDeletion': false,
        'items': [
          {
            'target': {'path': path, 'size': 1024, 'hash': 'hidden-hash'},
            'quarantinePath': 'hidden-recovery-path',
            'state': 'conflict',
            'reason': 'RESTORE_CONFLICT',
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: CopyScope(
            preferences: const {'language': 'both'},
            child: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: Scaffold(
                body: CleanupResults(
                  result: result,
                  visibleIndexes: {0},
                  selected: {},
                  busy: false,
                  onSelect: (_, __) {},
                  onRestore: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('操作已停止'), findsOneWidget);
      expect(find.textContaining('部分檔案未完成'), findsOneWidget);
      expect(find.textContaining('尚無完成結果的檔案'), findsOneWidget);
      final viewport = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('cleanup-results-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(viewport.position.maxScrollExtent, greaterThan(0));
      viewport.position.jumpTo(viewport.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final expansion = tester.widget<ExpansionTile>(
        find.byType(ExpansionTile),
      );
      expect(expansion.expansionAnimationStyle?.duration, Duration.zero);
      expect(expansion.expansionAnimationStyle?.reverseDuration, Duration.zero);
      await tester.tap(find.textContaining('檔案詳情'));
      await tester.pumpAndSettle();
      expect(find.text(path), findsOneWidget);
      expect(find.textContaining('hidden-hash'), findsNothing);
      expect(find.textContaining('hidden-recovery-path'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'conflict retry rereads the exact receipt before each confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <String>[];
      final requests = <Map<dynamic, dynamic>>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(Engine.channel, (call) async {
        final method = call.arguments['method'] as String;
        calls.add(method);
        if (method == 'cleanup.history')
          return {
            'ok': true,
            'result': {
              'receipts': [
                {
                  'id': 'receipt-1',
                  'itemCount': 1,
                  'quarantined': 1,
                  'restored': 0,
                  'conflicts': 0,
                  'skipped': 0,
                },
              ],
            },
          };
        if (method == 'cleanup.restore')
          requests.add(Map.of(call.arguments['params']));
        return {
          'ok': true,
          'result': {
            'receiptId': 'receipt-1',
            'recordedOnly': method == 'cleanup.details',
            'mutationPerformed': false,
            'cancelled': false,
            'partial': true,
            'items': [
              {
                'path': r'C:\fixture\conflict.tmp',
                'size': 12,
                'state': 'conflict',
                'reason': 'RESTORE_CONFLICT',
              },
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
      await tester.tap(find.text('Recovery history').first);
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(find.text('Review restoration'));
        await tester.tap(find.text('Review restoration'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(requests.length, i);
        await tester.tap(find.text('Confirm selected action'));
        await tester.pumpAndSettle();
        expect(requests.last, {'receiptId': 'receipt-1', 'confirmed': true});
      }
      expect(calls, [
        'cleanup.history',
        'cleanup.details',
        'cleanup.restore',
        'cleanup.details',
        'cleanup.restore',
      ]);
      expect(find.text('conflict.tmp'), findsOneWidget);
      expect(find.textContaining('Record 1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty history and unknown state remain explicit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CleanupResults(
            result: CleanupResult.parse('cleanup.history', {'receipts': []}),
            visibleIndexes: {},
            selected: {},
            busy: false,
            onSelect: (_, __) {},
            onRestore: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('No recovery receipts were found.'), findsOneWidget);
    expect(cleanupStateLabel('unexpected'), 'State unavailable');
  });
}
