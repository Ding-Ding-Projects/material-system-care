import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/driver_inventory.dart';
import 'package:material_system_care/localization.dart';
import 'package:material_system_care/frame_capture.dart';
import 'package:material_system_care/main.dart' as entry;

Map<String, dynamic> row(int n) => {
  'id': 'oem$n.inf',
  'originalName': 'device$n.inf',
  'provider': 'Example provider',
  'className': 'Display',
  'version': '10/10/2026 1.2.3.4',
  'signer': 'Example signer',
};
Map<String, dynamic> response([int n = 1]) => {
  'source': 'Windows driver store',
  'onlineCatalogueAvailable': false,
  'packages': <dynamic>[for (var i = 0; i < n; i++) row(i)],
};
Future<void> mount(
  WidgetTester t,
  DriverInventoryInvoke invoke, {
  bool reduced = true,
  bool bilingual = false,
  Size size = const Size(1200, 1000),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      home: CopyScope(
        preferences: {'language': bilingual ? 'both' : 'en'},
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(bilingual ? 2 : 1),
            disableAnimations: reduced,
          ),
          child: DriverInventoryPage(invoke: invoke),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> collect(WidgetTester t) async {
  await t.scrollUntilVisible(
    find.textContaining('Collect driver inventory'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await t.ensureVisible(find.textContaining('Collect driver inventory'));
  await t.tap(find.textContaining('Collect driver inventory'));
  await t.pumpAndSettle();
}

void main() {
  test('valid records preserve metadata and null signer is unknown', () {
    final v = response();
    v['packages'][0]['signer'] = null;
    final r = DriverInventory.parse(v);
    expect(r.packages.single.id, 'oem0.inf');
    expect(r.packages.single.version, '10/10/2026 1.2.3.4');
    expect(r.packages.single.signer, isNull);
    expect(DriverInventory.parse(response(0)).packages, isEmpty);
    expect(() => r.packages.clear(), throwsUnsupportedError);
  });
  final bad = <String, void Function(Map<String, dynamic>)>{
    'wrong source': (v) => v['source'] = 'online',
    'string flag': (v) => v['onlineCatalogueAvailable'] = 'false',
    'online flag': (v) => v['onlineCatalogueAvailable'] = true,
    'missing flag': (v) => v.remove('onlineCatalogueAvailable'),
    'missing rows': (v) => v.remove('packages'),
    'wrong rows': (v) => v['packages'] = {},
    'wrong row': (v) => v['packages'][0] = 'row',
    'path ID': (v) => v['packages'][0]['id'] = '../oem0.inf',
    'newline ID': (v) => v['packages'][0]['id'] = 'oem0.inf\n',
    'missing ID': (v) => v['packages'][0].remove('id'),
    'duplicate ID': (v) => v['packages'].add({...row(0), 'id': 'OEM0.INF'}),
    'missing metadata': (v) => v['packages'][0].remove('provider'),
    'numeric metadata': (v) => v['packages'][0]['version'] = 1,
    'embedded control': (v) =>
        v['packages'][0]['provider'] = 'name\u0000suffix',
    'C1 control': (v) => v['packages'][0]['provider'] = 'name\u0085',
    'Arabic direction mark': (v) => v['packages'][0]['signer'] = 'name\u061c',
    'left direction mark': (v) => v['packages'][0]['version'] = 'name\u200e',
    'right direction mark': (v) => v['packages'][0]['version'] = 'name\u200f',
    'bidi override': (v) => v['packages'][0]['signer'] = 'name\u202e',
    'oversized metadata': (v) => v['packages'][0]['originalName'] = 'a' * 4097,
    'oversized rows': (v) => v['packages'] = List.filled(25001, row(0)),
  };
  for (final b in bad.entries) {
    test('rejects ${b.key} without dropping rows', () {
      final v = response();
      b.value(v);
      expect(() => DriverInventory.parse(v), throwsFormatException);
    });
  }
  testWidgets('explicit read-only collection and selectable identity', (
    t,
  ) async {
    final calls = <String>[];
    await mount(t, (m, p) async {
      calls.add(m);
      expect(p, isEmpty);
      return response();
    });
    expect(calls, isEmpty);
    await collect(t);
    expect(calls, ['drivers.list']);
    await t.scrollUntilVisible(
      find.text('oem0.inf'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.text('oem0.inf'));
    await t.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is SelectableText && w.data == 'oem0.inf',
      ),
      findsOneWidget,
    );
    expect(find.text('Reported signer'), findsOneWidget);
    expect(find.text('Install'), findsNothing);
    expect(find.text('Export'), findsNothing);
  });
  testWidgets('failed refresh removes stale records and hides exception', (
    t,
  ) async {
    var n = 0;
    await mount(t, (_, __) async {
      if (++n == 1) return response();
      throw StateError('PRIVATE EXCEPTION');
    });
    await collect(t);
    await collect(t);
    expect(find.text('oem0.inf'), findsNothing);
    expect(find.textContaining('unavailable or invalid'), findsOneWidget);
    expect(find.textContaining('PRIVATE EXCEPTION'), findsNothing);
  });
  testWidgets('pending read disables duplicate and disposal ignores reply', (
    t,
  ) async {
    final p = Completer<Map<String, dynamic>>();
    var n = 0;
    await mount(t, (_, __) {
      n++;
      return p.future;
    });
    await t.tap(find.text('Collect driver inventory'));
    await t.pump();
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(n, 1);
    await t.pumpWidget(const SizedBox());
    p.complete(response());
    await t.pump();
    expect(t.takeException(), isNull);
  });
  for (final reduced in [false, true]) {
    testWidgets('persistent paging and expansion motion $reduced', (t) async {
      await mount(t, (_, __) async => response(50), reduced: reduced);
      await collect(t);
      final tiles = t.widgetList<ExpansionTile>(find.byType(ExpansionTile));
      expect(tiles, isNotEmpty);
      for (final tile in tiles) {
        expect(
          tile.expansionAnimationStyle?.duration,
          reduced ? Duration.zero : null,
        );
        expect(
          tile.expansionAnimationStyle?.reverseDuration,
          reduced ? Duration.zero : null,
        );
      }
      final s = t.widget<ListView>(find.byType(ListView)).controller!;
      final f = t
          .widget<Focus>(
            find.byWidgetPredicate(
              (w) =>
                  w is Focus &&
                  w.focusNode?.debugLabel == 'Driver inventory paging',
            ),
          )
          .focusNode!;
      f.requestFocus();
      await t.pump();
      final start = s.offset;
      await t.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await t.pump();
      if (!reduced) {
        await t.pump(const Duration(milliseconds: 40));
        expect(s.offset, greaterThan(start));
      }
      await t.pumpAndSettle();
      final middle = s.offset;
      await t.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await t.pumpAndSettle();
      expect(s.offset, greaterThan(middle));
      expect(f.hasPrimaryFocus, isTrue);
      await t.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await t.pumpAndSettle();
      expect(s.offset, lessThan(middle + 900));
    });
  }
  testWidgets('minimum bilingual large text long metadata', (t) async {
    final v = response();
    v['packages'][0]['provider'] = 'Provider ' * 100;
    await mount(
      t,
      (_, __) async => v,
      bilingual: true,
      size: const Size(800, 600),
    );
    await collect(t);
    if (find.byTooltip('Close').evaluate().isNotEmpty) {
      await t.tap(find.byTooltip('Close'));
      await t.pumpAndSettle();
    }
    await t.scrollUntilVisible(
      find.text('oem0.inf'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await t.ensureVisible(find.text('oem0.inf'));
    await t.tap(find.text('oem0.inf'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.scrollUntilVisible(
      find.textContaining('Collect driver inventory'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('收集驅動程式清單'), findsOneWidget);
  });
  testWidgets('actual isolated CareApp opens review without automatic read', (
    t,
  ) async {
    final calls = <String>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      entry.Engine.channel,
      (call) async {
        calls.add(call.method);
        return {'ok': true, 'result': response()};
      },
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        entry.Engine.channel,
        null,
      ),
    );
    await t.pumpWidget(
      const entry.CareApp(startDriverInventory: true, isolatedCapture: true),
    );
    await t.pumpAndSettle();
    expect(find.byType(DriverInventoryPage), findsOneWidget);
    expect(calls, isEmpty);
    await t.tap(find.textContaining('Collect driver inventory'));
    await t.pumpAndSettle();
    expect(calls, ['invoke']);
  });
  testWidgets('capture entry is isolated and rejects competing destinations', (
    t,
  ) async {
    const args = [
      '--driver-inventory',
      '--capture-frame=C:/unused-drivers.png',
      '--capture-language=both',
      '--capture-theme=dark',
      '--capture-text-scale=2',
      '--capture-motion=reduced',
    ];
    entry.main(args);
    await t.pump();
    expect(find.byType(FrameCapture), findsOneWidget);
    expect(find.byType(DriverInventoryPage), findsOneWidget);
    final app = t.widget<entry.CareApp>(find.byType(entry.CareApp));
    expect(app.isolatedCapture, isTrue);
    expect(app.capturePreferences['language'], 'both');
    await t.pumpWidget(const SizedBox());
    entry.main([...args, '--system-overview']);
    await t.pump();
    expect(find.byType(FrameCapture), findsNothing);
    expect(
      t.widget<entry.CareApp>(find.byType(entry.CareApp)).capturePreferences,
      isEmpty,
    );
    await t.pumpWidget(const SizedBox());
  });
}
