import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/system_overview.dart';
import 'package:material_system_care/localization.dart';
import 'package:material_system_care/provenance.dart';
import 'package:material_system_care/main.dart' as entry;
import 'package:material_system_care/frame_capture.dart';

Map<String, dynamic> snapshot() => {
  'measuredAt': '2026-10-10T12:00:00.1234567+00:00',
  'fixtureDataRoot': false,
  'measurementSource': 'live-machine',
  'cpu': <String, dynamic>{'logicalProcessors': 8},
  'os': {'description': 'Microsoft Windows 11', 'architecture': 'X64'},
  'memory': {
    'available': true,
    'totalBytes': 1000,
    'availableBytes': 400,
    'loadPercent': 60,
  },
  'drives': <dynamic>[
    {
      'id': 'C:\\',
      'name': 'C:\\',
      'ready': true,
      'totalBytes': 2000,
      'freeBytes': 500,
      'format': 'NTFS',
    },
    {
      'id': 'D:\\',
      'name': 'D:\\',
      'ready': false,
      'totalBytes': null,
      'freeBytes': null,
      'format': null,
    },
  ],
};
Map<String, dynamic> ping() => {
  'manifest': {'version': '0.1.0'},
  'buildReceipt': {'version': '1.2.3', 'builtUtc': '2026-10-09T09:00:00Z'},
};

Future<void> mount(
  WidgetTester tester,
  SystemOverviewInvoke invoke, {
  bool reduced = true,
  bool bilingual = false,
  Size size = const Size(1200, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: CopyScope(
        preferences: {'language': bilingual ? 'both' : 'en'},
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(bilingual ? 2 : 1),
            disableAnimations: reduced,
          ),
          child: SystemOverviewPage(
            invoke: invoke,
            now: () => DateTime.utc(2026, 10, 10, 12, 1),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> refresh(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.textContaining('Refresh measurements'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.textContaining('Refresh measurements'));
  await tester.tap(find.textContaining('Refresh measurements'));
  await tester.pumpAndSettle();
}

void main() {
  test('snapshot preserves measured values and explicit unavailability', () {
    final value = SystemSample.parse(snapshot());
    expect(value.memory!.used, 600);
    expect(value.logicalProcessors, 8);
    expect(value.drives.first.free, 500);
    expect(value.partial, isTrue);
    expect(value.drives.last.reason, 'Drive is not ready.');
    final raw = snapshot();
    raw['memory'] = {
      'available': false,
      'totalBytes': null,
      'availableBytes': null,
      'loadPercent': null,
    };
    expect(SystemSample.parse(raw).memory, isNull);
  });
  final invalid = <String, void Function(Map<String, dynamic>)>{
    'missing time': (v) => v.remove('measuredAt'),
    'invalid date': (v) => v['measuredAt'] = '2026-02-30T12:00:00Z',
    'local time': (v) => v['measuredAt'] = '2026-10-10T12:00:00',
    'non UTC time': (v) => v['measuredAt'] = '2026-10-10T12:00:00+01:00',
    'invalid source': (v) => v['measurementSource'] = 'fixture',
    'invalid fixture flag': (v) => v['fixtureDataRoot'] = 1,
    'missing cpu': (v) => v.remove('cpu'),
    'zero processor count': (v) => v['cpu']['logicalProcessors'] = 0,
    'fractional processor count': (v) => v['cpu']['logicalProcessors'] = 1.5,
    'excessive processor count': (v) => v['cpu']['logicalProcessors'] = 65537,
    'control description': (v) => v['os']['description'] = 'bad\u0000value',
    'long description': (v) => v['os']['description'] = 'x' * 1025,
    'missing architecture': (v) => v['os'].remove('architecture'),
    'string memory flag': (v) => v['memory']['available'] = 'true',
    'unsafe memory integer': (v) =>
        v['memory']['totalBytes'] = 9007199254740992,
    'memory capacity contradiction': (v) =>
        v['memory']['availableBytes'] = 1001,
    'zero total memory': (v) => v['memory']['totalBytes'] = 0,
    'invalid load': (v) => v['memory']['loadPercent'] = 101,
    'unavailable memory values': (v) => v['memory']['available'] = false,
    'missing drives': (v) => v.remove('drives'),
    'too many drives': (v) => v['drives'] = List.filled(27, v['drives'][0]),
    'malformed drive': (v) => v['drives'][0] = null,
    'duplicate drive': (v) => v['drives'][1] = v['drives'][0],
    'nonroot drive': (v) => v['drives'][0]['id'] = r'C:\folder',
    'mismatched drive name': (v) => v['drives'][0]['name'] = 'E:\\',
    'numeric ready flag': (v) => v['drives'][0]['ready'] = 1,
    'drive capacity contradiction': (v) => v['drives'][0]['freeBytes'] = 2001,
    'negative drive size': (v) => v['drives'][0]['totalBytes'] = -1,
    'unsafe drive size': (v) => v['drives'][0]['totalBytes'] = 9007199254740992,
    'invalid format': (v) => v['drives'][0]['format'] = 'x' * 65,
    'unavailable drive values': (v) => v['drives'][1]['freeBytes'] = 1,
    'unknown unavailable reason': (v) =>
        v['drives'][1]['unavailableReason'] = 'raw exception',
    'contradictory ready reason': (v) =>
        v['drives'][0]['unavailableReason'] = 'Volume access is unavailable.',
  };
  for (final item in invalid.entries) {
    test('snapshot rejects ${item.key}', () {
      final value = snapshot();
      item.value(value);
      expect(() => SystemSample.parse(value), throwsFormatException);
    });
  }
  testWidgets(
    'overview refresh is explicit and build provenance stays independent',
    (tester) async {
      final calls = <String>[];
      await mount(tester, (method, _) async {
        calls.add(method);
        return method == 'engine.ping' ? ping() : snapshot();
      });
      expect(calls, ['engine.ping']);
      expect(find.byType(BuildProvenance), findsOneWidget);
      expect(find.text('Version: 1.2.3'), findsOneWidget);
      await refresh(tester);
      expect(calls, ['engine.ping', 'system.snapshot']);
      expect(
        find.text('Sample age at this render (seconds): 59'),
        findsOneWidget,
      );
      expect(find.text('Logical processors: 8'), findsOneWidget);
      expect(find.text('Reported memory load: 60%'), findsOneWidget);
      expect(find.text('Version: 1.2.3'), findsOneWidget);
      expect(
        find.textContaining('Some measurements are unavailable'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'malformed refresh removes stale values and does not reflect raw errors',
    (tester) async {
      var calls = 0;
      await mount(tester, (method, _) async {
        if (method == 'engine.ping') return ping();
        if (calls++ == 0) return snapshot();
        return {...snapshot(), 'measurementSource': 'private raw detail'};
      });
      await refresh(tester);
      expect(find.text('Logical processors: 8'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await refresh(tester);
      expect(find.text('Logical processors: 8'), findsNothing);
      expect(find.textContaining('private raw detail'), findsNothing);
      expect(
        find.text(
          'Machine measurements are unavailable or invalid. Refresh to try again.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'pending refresh rejects reentry and safely completes after disposal',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      var calls = 0;
      await mount(tester, (method, _) async {
        if (method == 'engine.ping') return ping();
        calls++;
        return pending.future;
      });
      final action = tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Refresh measurements'),
          )
          .onPressed!;
      action();
      action();
      await tester.pump();
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
      pending.complete(snapshot());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  for (final reduced in [true, false]) {
    testWidgets(
      'overview memory and drive motion is bounded reduced=$reduced',
      (tester) async {
        await mount(
          tester,
          (method, _) async => method == 'engine.ping' ? ping() : snapshot(),
          reduced: reduced,
        );
        await tester.tap(find.text('Refresh measurements'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        final indicator = find.byWidgetPredicate(
          (w) => w is LinearProgressIndicator && w.value != null,
        );
        final value = tester
            .widget<LinearProgressIndicator>(indicator.first)
            .value!;
        expect(value, reduced ? .6 : lessThan(.6));
        if (!reduced) expect(value, greaterThan(0));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        final tile = find.ancestor(
          of: find
              .byWidgetPredicate((w) => w is Text && w.data == 'C:\\')
              .first,
          matching: find.byType(ExpansionTile),
        );
        await tester.ensureVisible(tile);
        final collapsed = tester.getSize(tile).height;
        await tester.tap(find.text('C:\\'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        final middle = tester.getSize(tile).height;
        await tester.pumpAndSettle();
        final expanded = tester.getSize(tile).height;
        expect(expanded, greaterThan(collapsed));
        expect(middle, reduced ? expanded : lessThan(expanded));
        expect(find.text('Free bytes: 500'), findsOneWidget);
        await tester.tap(find.text('C:\\').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        final reverse = tester.getSize(tile).height;
        await tester.pumpAndSettle();
        expect(reverse, reduced ? collapsed : greaterThan(collapsed));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('unavailable memory and future sample time are explicit', (
    tester,
  ) async {
    final value = snapshot();
    value['measuredAt'] = '2027-01-01T00:00:00Z';
    value['memory'] = {
      'available': false,
      'totalBytes': null,
      'availableBytes': null,
      'loadPercent': null,
    };
    await mount(
      tester,
      (method, _) async => method == 'engine.ping' ? ping() : value,
    );
    await refresh(tester);
    expect(
      find.text('The sample time is ahead of the display clock.'),
      findsOneWidget,
    );
    expect(
      find.text('Physical memory measurements are unavailable.'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is LinearProgressIndicator && w.value != null,
      ),
      findsNothing,
    );
  });
  testWidgets(
    'Home uses the dedicated overview without automatic measurement polling',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final methods = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(entry.Engine.channel, (call) async {
        final method = (call.arguments as Map)['method'] as String;
        methods.add(method);
        return {
          'ok': true,
          'result': method == 'engine.ping' ? ping() : snapshot(),
        };
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(entry.Engine.channel, null),
      );
      await tester.pumpWidget(
        const entry.CareApp(
          isolatedCapture: true,
          capturePreferences: {
            'language': 'both',
            'textScale': 2.0,
            'reducedMotion': true,
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SystemOverviewPage), findsOneWidget);
      await tester.pump(const Duration(minutes: 1));
      expect(methods, ['engine.ping']);
      expect(find.byType(BuildProvenance), findsOneWidget);
      await refresh(tester);
      expect(methods, ['engine.ping', 'system.snapshot']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('bilingual minimum overview remains keyboard pageable', (
    tester,
  ) async {
    final value = snapshot();
    value['drives'] = List.generate(
      26,
      (i) => {
        'id': '${String.fromCharCode(65 + i)}:\\',
        'name': '${String.fromCharCode(65 + i)}:\\',
        'ready': false,
        'unavailableReason': 'Volume access is unavailable.',
      },
    );
    await mount(
      tester,
      (method, _) async => method == 'engine.ping' ? ping() : value,
      bilingual: true,
      size: const Size(800, 600),
    );
    await refresh(tester);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    final focus = tester.widget<Focus>(
      find.byWidgetPredicate(
        (w) =>
            w is Focus && w.focusNode?.debugLabel == 'System overview paging',
      ),
    );
    focus.focusNode!.requestFocus();
    await tester.pump();
    final scroller = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    var previous = scroller.position.pixels;
    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(scroller.position.pixels, greaterThan(previous));
      previous = scroller.position.pixels;
    }
    await tester.scrollUntilVisible(
      find.text('Z:\\'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Z:\\'));
    await tester.tap(find.text('Z:\\'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Volume access is unavailable.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  testWidgets('system overview capture is exclusive and isolated', (
    tester,
  ) async {
    const args = [
      '--system-overview',
      '--capture-frame=C:/unused-overview.png',
      '--capture-language=both',
      '--capture-theme=dark',
      '--capture-text-scale=2',
      '--capture-motion=reduced',
    ];
    entry.main(args);
    await tester.pump();
    expect(find.byType(FrameCapture), findsOneWidget);
    expect(find.byType(SystemOverviewPage), findsOneWidget);
    final context = tester.element(find.byType(SystemOverviewPage));
    expect(CopyScope.of(context)['language'], 'both');
    await tester.pumpWidget(const SizedBox());
    entry.main([...args, '--packages']);
    await tester.pump();
    expect(find.byType(FrameCapture), findsNothing);
    expect(
      tester
          .widget<entry.CareApp>(find.byType(entry.CareApp))
          .capturePreferences,
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
