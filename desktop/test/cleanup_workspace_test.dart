import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/cleanup_workspace.dart';
import 'package:material_system_care/cleanup.dart';
import 'package:material_system_care/localization.dart';
import 'package:material_system_care/main.dart' as entry;
import 'package:material_system_care/frame_capture.dart';

Map<String, dynamic> scan([int n = 2]) => {
  'fixture': true,
  'planId': 'a' * 32,
  'root': r'C:\fixture',
  'category': 'aged-user-temp-files',
  'minimumAgeDays': 7,
  'expiresUtc': DateTime.now()
      .toUtc()
      .add(const Duration(hours: 1))
      .toIso8601String(),
  'totalBytes': n,
  'truncated': false,
  'inaccessible': 0,
  'reparseSkipped': 0,
  'unavailable': 0,
  'mutationPerformed': false,
  'targets': <dynamic>[
    for (var i = 0; i < n; i++)
      <String, dynamic>{'path': r'C:\fixture\' + 'file$i.tmp', 'size': 1},
  ],
};
Future<void> mount(
  WidgetTester t,
  CleanupInvoke invoke, {
  Future<bool> Function(String)? cancel,
  bool reduced = true,
  bool large = false,
}) async {
  t.view.physicalSize = large ? const Size(800, 600) : const Size(1400, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      home: CopyScope(
        preferences: {'language': large ? 'both' : 'en'},
        child: MediaQuery(
          data: MediaQueryData(
            size: t.view.physicalSize,
            disableAnimations: reduced,
            textScaler: TextScaler.linear(large ? 2 : 1),
          ),
          child: CleanupWorkspace(
            invoke: invoke,
            cancel: cancel ?? (_) async => true,
            onRecovery: (_) {},
            fixture: true,
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> start(WidgetTester t) async {
  await t.tap(find.textContaining('Scan recoverable cleanup'));
  await t.pumpAndSettle();
}

void main() {
  test('strict plan preserves scope and indexes', () {
    final p = CleanupPlan.parse(scan(), fixture: true);
    expect(p.result.files.map((f) => f.index), [0, 1]);
    expect(p.root, r'C:\fixture');
  });
  final bad = <String, void Function(Map<String, dynamic>)>{
    'fixture mismatch': (v) => v['fixture'] = false,
    'root missing': (v) => v.remove('root'),
    'network root': (v) => v['root'] = r'\\server\share',
    'volume root': (v) => v['root'] = r'C:\',
    'outside target': (v) => v['targets'][0]['path'] = r'C:\elsewhere\a.tmp',
    'duplicate target': (v) =>
        v['targets'][1]['path'] = v['targets'][0]['path'],
    'wrong total': (v) => v['totalBytes'] = 5,
    'missing size': (v) => v['targets'][0].remove('size'),
    'wrong category': (v) => v['category'] = 'all-files',
    'wrong age': (v) => v['minimumAgeDays'] = 1,
    'invalid identity': (v) => v['planId'] = 'arbitrary',
    'expired': (v) => v['expiresUtc'] = DateTime.now()
        .toUtc()
        .subtract(const Duration(seconds: 1))
        .toIso8601String(),
    'invalid calendar': (v) => v['expiresUtc'] = '2026-02-31T00:00:00Z',
    'missing count': (v) => v.remove('unavailable'),
    'negative count': (v) => v['inaccessible'] = -1,
  };
  for (final e in bad.entries)
    test('rejects ${e.key}', () {
      final v = scan();
      e.value(v);
      expect(() => CleanupPlan.parse(v, fixture: true), throwsFormatException);
    });
  testWidgets(
    'read cancellation awaits terminal and completed race stays success',
    (t) async {
      var pending = Completer<Map<String, dynamic>>();
      String? id;
      final ids = <String>[];
      await mount(
        t,
        (m, p, {requestId}) {
          expect(m, 'cleanup.scan');
          expect(p, {
            'minimumAgeDays': 7,
            'maxEntries': 10000,
            'maxHashMiB': 512,
          });
          id = requestId;
          return pending.future;
        },
        cancel: (value) async {
          ids.add(value);
          return true;
        },
      );
      await t.tap(find.text('Scan recoverable cleanup'));
      await t.pump();
      await t.tap(find.text('Cancel scan'));
      await t.pump();
      expect(ids, [id]);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      pending.completeError(PlatformException(code: 'ENGINE_CANCELLED'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Stopped waiting for cleanup scan'),
        findsOneWidget,
      );
      expect(find.byType(CleanupResults), findsNothing);
      pending = Completer<Map<String, dynamic>>();
      await t.tap(find.text('Scan recoverable cleanup'));
      await t.pump();
      await t.tap(find.text('Cancel scan'));
      await t.pump();
      pending.complete(scan());
      await t.pumpAndSettle();
      expect(find.byType(CleanupResults), findsOneWidget);
      expect(
        find.textContaining('Stopped waiting for cleanup scan'),
        findsNothing,
      );
    },
  );
  testWidgets(
    'failed rescan removes stale plan and disposal ignores late response',
    (t) async {
      var count = 0;
      final pending = Completer<Map<String, dynamic>>();
      await mount(t, (m, p, {requestId}) {
        count++;
        return count == 1 ? Future.value(scan()) : pending.future;
      });
      await start(t);
      await t.tap(find.text('Scan recoverable cleanup'));
      await t.pump();
      expect(find.byType(CleanupResults), findsNothing);
      await t.pumpWidget(const SizedBox());
      pending.complete(scan());
      await t.pump();
      expect(t.takeException(), isNull);
    },
  );
  for (final wrongTarget in [false, true])
    testWidgets('mismatched receipt or target is not displayed $wrongTarget', (
      t,
    ) async {
      await mount(
        t,
        (m, p, {requestId}) async => m == 'cleanup.scan'
            ? scan()
            : {
                'receiptId': (wrongTarget ? 'a' : 'b') * 32,
                'items': wrongTarget
                    ? [
                        {
                          'target': {
                            'path': r'C:\fixture\file1.tmp',
                            'size': 1,
                          },
                          'state': 'quarantined',
                        },
                      ]
                    : [],
                'partial': true,
                'cancelled': false,
                'plannedCount': 1,
                'permanentDeletion': false,
              },
      );
      await start(t);
      await t.tap(find.widgetWithText(CheckboxListTile, 'file0.tmp'));
      await t.pump();
      await t.tap(find.text('Apply selected cleanup targets'));
      await t.pumpAndSettle();
      await t.tap(find.text('Confirm selected action'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Cleanup could not be confirmed'),
        findsOneWidget,
      );
      expect(find.byType(CleanupResults), findsNothing);
    });
  for (final reduced in [true, false])
    testWidgets('persistent paging and reduced motion $reduced', (t) async {
      await mount(t, (m, p, {requestId}) async => scan(40), reduced: reduced);
      await start(t);
      final f = t
          .widget<Focus>(
            find.byWidgetPredicate(
              (w) => w is Focus && w.focusNode?.debugLabel == 'Cleanup paging',
            ),
          )
          .focusNode!;
      final s = t
          .widget<CleanupResults>(find.byType(CleanupResults))
          .controller!;
      f.requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await t.pump();
      if (!reduced) {
        await t.pump(const Duration(milliseconds: 40));
        expect(s.offset, greaterThan(0));
      }
      await t.pumpAndSettle();
      final first = s.offset;
      await t.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await t.pumpAndSettle();
      expect(s.offset, greaterThan(first));
      expect(f.hasPrimaryFocus, isTrue);
    });
  testWidgets('minimum bilingual controls and results do not overflow', (
    t,
  ) async {
    await mount(t, (m, p, {requestId}) async => scan(), large: true);
    await t.scrollUntilVisible(
      find.textContaining('Scan recoverable cleanup'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await start(t);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'fixture capture entry uses dedicated workspace with no automatic reads',
    (t) async {
      entry.main([
        '--cleanup-fixture-root=C:/unused',
        '--capture-frame=C:/unused.png',
        '--capture-language=both',
        '--capture-theme=dark',
        '--capture-text-scale=2',
        '--capture-motion=reduced',
      ]);
      await t.pump();
      expect(find.byType(CleanupWorkspace), findsOneWidget);
      expect(find.byType(FrameCapture), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('dedicated fixture opens only cleanup recovery history', (
    t,
  ) async {
    final calls = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      entry.Engine.channel,
      (call) async {
        calls.add((call.arguments as Map)['method'] as String);
        return {
          'ok': true,
          'result': {'receipts': []},
        };
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        entry.Engine.channel,
        null,
      ),
    );
    await t.pumpWidget(
      const entry.CareApp(cleanupFixture: true, isolatedCapture: true),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Recovery history'));
    await t.pumpAndSettle();
    expect(calls, ['cleanup.history']);
    expect(find.text('No recovery receipts were found.'), findsOneWidget);
  });
}
