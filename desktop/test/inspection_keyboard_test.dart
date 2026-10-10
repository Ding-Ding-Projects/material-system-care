import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/main.dart';

void main() {
  testWidgets(
    'inspection pages reach lower controls with Page Down on Windows',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const preferences = {
        'language': 'both',
        'theme': 'dark',
        'textScale': 2.0,
        'reducedMotion': true,
      };
      for (final entry in <String, CareApp>{
        'services': const CareApp(
          startServices: true,
          isolatedCapture: true,
          capturePreferences: preferences,
        ),
        'scheduled tasks': const CareApp(
          startScheduledTasks: true,
          isolatedCapture: true,
          capturePreferences: preferences,
        ),
        'processes': const CareApp(
          startProcesses: true,
          isolatedCapture: true,
          capturePreferences: preferences,
        ),
      }.entries) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(entry.value);
        await tester.pumpAndSettle();
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        expect(
          scrollable.position.maxScrollExtent,
          greaterThan(0),
          reason: entry.key,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final before = scrollable.position.pixels;
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.pumpAndSettle();
        expect(
          scrollable.position.pixels,
          greaterThan(before),
          reason: entry.key,
        );
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
