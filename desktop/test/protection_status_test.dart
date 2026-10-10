import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/protection_status.dart';
import 'package:material_system_care/localization.dart';
import 'package:material_system_care/main.dart' as entry;
import 'package:material_system_care/frame_capture.dart';

Map<String, dynamic> response() => {
  'defender': <String, dynamic>{
    'AMServiceEnabled': true,
    'AntivirusEnabled': true,
    'AntispywareEnabled': null,
    'RealTimeProtectionEnabled': true,
    'BehaviorMonitorEnabled': false,
    'IoavProtectionEnabled': true,
    'NISEnabled': true,
    'RebootRequired': false,
    'AntivirusSignatureVersion': '1.437.371.0',
    'AntivirusSignatureLastUpdated': '/Date(1791633600000)/',
    'QuickScanStartTime': '/Date(1791633600000-0400)/',
    'QuickScanEndTime': null,
    'FullScanStartTime': null,
    'FullScanEndTime': null,
  },
  'defenderUnavailableReason': null,
  'firewall': <dynamic>[
    {
      'Name': 'Domain',
      'Enabled': 1,
      'DefaultInboundAction': 4,
      'DefaultOutboundAction': 2,
    },
    {
      'Name': 'Private',
      'Enabled': 0,
      'DefaultInboundAction': 4,
      'DefaultOutboundAction': 2,
    },
    {
      'Name': 'Public',
      'Enabled': 2,
      'DefaultInboundAction': 0,
      'DefaultOutboundAction': 0,
    },
  ],
  'firewallUnavailableReason': null,
};
Future<void> mount(
  WidgetTester tester,
  ProtectionStatusInvoke invoke, {
  bool bilingual = false,
  bool reduced = true,
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
          child: ProtectionStatusPage(invoke: invoke),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> refresh(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.textContaining('Refresh protection status'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.textContaining('Refresh protection status'));
  await tester.tap(find.textContaining('Refresh protection status'));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'provider booleans, numeric firewall enums and PowerShell dates retain their meaning',
    () {
      final status = ProtectionStatus.parse(response());
      expect(status.defender!.flags['BehaviorMonitorEnabled'], isFalse);
      expect(status.defender!.flags['AntispywareEnabled'], isNull);
      expect(status.firewall!.map((p) => p.enabled), [1, 0, 2]);
      expect(
        status.defender!.dates['AntivirusSignatureLastUpdated'],
        DateTime.utc(2026, 10, 10, 12),
      );
      expect(
        status.defender!.dates['QuickScanStartTime'],
        DateTime.utc(2026, 10, 10, 12),
      );
      expect(parseProtectionDate('/Date(-62135596800000)/'), DateTime.utc(1));
    },
  );
  final invalid = <String, void Function(Map<String, dynamic>)>{
    'missing provider': (v) => v.remove('defender'),
    'missing reason': (v) => v.remove('firewallUnavailableReason'),
    'contradictory defender reason': (v) => v['defenderUnavailableReason'] =
        'Defender status is unavailable on this installation or for this account.',
    'missing flag': (v) => v['defender'].remove('AntivirusEnabled'),
    'numeric defender flag': (v) => v['defender']['AntivirusEnabled'] = 1,
    'string defender flag': (v) => v['defender']['RebootRequired'] = 'false',
    'missing signature': (v) =>
        v['defender'].remove('AntivirusSignatureVersion'),
    'oversized signature': (v) =>
        v['defender']['AntivirusSignatureVersion'] = 'x' * 129,
    'control signature': (v) =>
        v['defender']['AntivirusSignatureVersion'] = 'bad\u0000value',
    'missing date': (v) => v['defender'].remove('FullScanEndTime'),
    'unrecognized date format': (v) =>
        v['defender']['QuickScanStartTime'] = '2026-10-10T12:00:00Z',
    'numeric date': (v) => v['defender']['QuickScanStartTime'] = 1791633600000,
    'out of range date': (v) =>
        v['defender']['QuickScanStartTime'] = '/Date(253402300800000)/',
    'invalid date offset': (v) =>
        v['defender']['QuickScanStartTime'] = '/Date(1791633600000+1560)/',
    'unknown unavailable defender reason': (v) {
      v['defender'] = null;
      v['defenderUnavailableReason'] = 'raw failure';
    },
    'missing firewall row': (v) => v['firewall'].removeLast(),
    'too many firewall rows': (v) => v['firewall'].add(v['firewall'][0]),
    'malformed profile': (v) => v['firewall'][0] = null,
    'unknown profile': (v) => v['firewall'][0]['Name'] = 'Other',
    'duplicate profile': (v) => v['firewall'][1]['Name'] = 'Domain',
    'boolean firewall enum': (v) => v['firewall'][0]['Enabled'] = true,
    'invalid firewall enum': (v) => v['firewall'][0]['Enabled'] = 3,
    'invalid action enum': (v) => v['firewall'][0]['DefaultInboundAction'] = 1,
    'missing action enum': (v) =>
        v['firewall'][0].remove('DefaultOutboundAction'),
    'contradictory firewall reason': (v) => v['firewallUnavailableReason'] =
        'Firewall status is unavailable for this account.',
  };
  for (final item in invalid.entries) {
    test('protection parser rejects ${item.key}', () {
      final value = response();
      item.value(value);
      expect(() => ProtectionStatus.parse(value), throwsFormatException);
    });
  }
  testWidgets(
    'refresh alone reads status and no scan or configuration method',
    (tester) async {
      final methods = <String>[];
      await mount(tester, (method, params) async {
        methods.add(method);
        expect(params, isEmpty);
        return response();
      });
      await tester.pump(const Duration(minutes: 1));
      expect(methods, isEmpty);
      await refresh(tester);
      expect(methods, ['security.status']);
      expect(find.text('Antivirus signature version'), findsOneWidget);
      expect(find.text('1.437.371.0'), findsOneWidget);
      expect(find.textContaining('threat-free'), findsOneWidget);
      expect(find.text('Quick scan'), findsNothing);
      expect(find.text('Reboot'), findsNothing);
    },
  );
  for (final source in ['defender', 'firewall']) {
    testWidgets(
      '$source unavailable reason is separate from the available source',
      (tester) async {
        final value = response();
        value[source] = null;
        value['${source}UnavailableReason'] = source == 'defender'
            ? 'Defender status is unavailable on this installation or for this account.'
            : 'Firewall status is unavailable for this account.';
        await mount(tester, (_, __) async => value);
        await refresh(tester);
        final reason = value['${source}UnavailableReason'] as String;
        await tester.scrollUntilVisible(
          find.text(reason),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(reason), findsOneWidget);
        expect(
          find.text(
            'Protection status is unavailable or invalid. Refresh to try again.',
          ),
          findsNothing,
        );
      },
    );
  }
  testWidgets(
    'failed refresh clears stale status and never reflects raw exception',
    (tester) async {
      var calls = 0;
      await mount(tester, (_, __) async {
        if (calls++ == 0) return response();
        throw StateError('private raw detail');
      });
      await refresh(tester);
      expect(find.text('1.437.371.0'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      await refresh(tester);
      expect(find.text('1.437.371.0'), findsNothing);
      expect(find.textContaining('private raw detail'), findsNothing);
      expect(
        find.text(
          'Protection status is unavailable or invalid. Refresh to try again.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'pending read prevents reentry and ignores completion after disposal',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      var calls = 0;
      await mount(tester, (_, __) {
        calls++;
        return pending.future;
      });
      final action = tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Refresh protection status'),
          )
          .onPressed!;
      action();
      action();
      await tester.pump();
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
      pending.complete(response());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  for (final reduced in [true, false]) {
    testWidgets(
      'bilingual protection paging and expansion respect motion reduced=$reduced',
      (tester) async {
        await mount(
          tester,
          (_, __) async => response(),
          bilingual: true,
          reduced: reduced,
          size: const Size(800, 600),
        );
        await refresh(tester);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        final focus = tester.widget<Focus>(
          find.byWidgetPredicate(
            (w) =>
                w is Focus &&
                w.focusNode?.debugLabel == 'Protection status paging',
          ),
        );
        focus.focusNode!.requestFocus();
        await tester.pump();
        final scroller = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        var before = scroller.position.pixels;
        for (var i = 0; i < 3; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
          if (!reduced && i == 0) {
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 40));
            expect(scroller.position.pixels, greaterThan(before));
          }
          await tester.pumpAndSettle();
          expect(scroller.position.pixels, greaterThan(before));
          before = scroller.position.pixels;
        }
        final title = find.textContaining('Public firewall profile');
        await tester.scrollUntilVisible(
          title,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(title);
        await tester.pumpAndSettle();
        final tile = find.ancestor(
          of: title,
          matching: find.byType(ExpansionTile),
        );
        final collapsed = tester.getSize(tile).height;
        await tester.tap(title);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        final middle = tester.getSize(tile).height;
        await tester.pumpAndSettle();
        final expanded = tester.getSize(tile).height;
        expect(expanded, greaterThan(collapsed));
        expect(middle, reduced ? expanded : lessThan(expanded));
        if (!reduced) expect(middle, greaterThan(collapsed));
        await tester.ensureVisible(title);
        await tester.tap(title);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        final reverse = tester.getSize(tile).height;
        await tester.pumpAndSettle();
        expect(reverse, reduced ? collapsed : greaterThan(collapsed));
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
  testWidgets(
    'protection route preserves separate scan action and does not start status read',
    (tester) async {
      final methods = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(entry.Engine.channel, (call) async {
        methods.add((call.arguments as Map)['method'] as String);
        return {'ok': true, 'result': <String, dynamic>{}};
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(entry.Engine.channel, null),
      );
      await tester.pumpWidget(const entry.CareApp(isolatedCapture: true));
      await tester.pumpAndSettle();
      tester
          .widget<NavigationRail>(find.byType(NavigationRail))
          .onDestinationSelected!(4);
      await tester.pumpAndSettle();
      expect(find.text('Quick scan'), findsOneWidget);
      await tester.tap(find.text('Protection status'));
      await tester.pumpAndSettle();
      expect(find.byType(ProtectionStatusPage), findsOneWidget);
      expect(methods, ['engine.ping']);
    },
  );
  testWidgets('protection capture route is exclusive and isolated', (
    tester,
  ) async {
    const args = [
      '--protection-status',
      '--capture-frame=C:/unused-protection.png',
      '--capture-language=both',
      '--capture-theme=dark',
      '--capture-text-scale=2',
      '--capture-motion=reduced',
    ];
    entry.main(args);
    await tester.pump();
    expect(find.byType(FrameCapture), findsOneWidget);
    expect(find.byType(ProtectionStatusPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    entry.main([...args, '--system-overview']);
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
