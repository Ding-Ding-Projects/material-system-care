import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/frame_capture.dart';
import 'package:material_system_care/localization.dart';
import 'package:material_system_care/main.dart' as entry;

void main() {
  const arguments = [
    '--cleanup-fixture-root',
    r'C:\fixture-test-only',
    '--capture-frame=C:/unused-fixture.png',
    '--capture-language=both',
    '--capture-theme=dark',
    '--capture-text-scale=1.5',
    '--capture-motion=reduced',
  ];

  testWidgets('fixture-only entrypoint applies the isolated capture tuple', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    entry.main(arguments);
    await tester.pump();
    expect(find.byType(FrameCapture), findsOneWidget);
    final capture = tester.widget<FrameCapture>(find.byType(FrameCapture));
    expect(capture.output, 'C:/unused-fixture.png');
    final app = tester.widget<entry.CareApp>(find.byType(entry.CareApp));
    expect(app.cleanupFixture, isTrue);
    expect(app.isolatedCapture, isTrue);
    final context = tester.element(find.byType(entry.WorkflowPage));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(CopyScope.of(context)['language'], 'both');
    expect(MediaQuery.textScalerOf(context).scale(12), 18);
    expect(MediaQuery.disableAnimationsOf(context), isTrue);
    expect(
      find.text('Disposable cleanup verification only · 僅供即棄清理驗證'),
      findsOneWidget,
    );
    expect(find.byType(NavigationRail), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'fixture and another destination do not export or apply overrides',
    (tester) async {
      entry.main([...arguments, '--services']);
      await tester.pump();
      expect(find.byType(FrameCapture), findsNothing);
      final app = tester.widget<entry.CareApp>(find.byType(entry.CareApp));
      expect(app.cleanupFixture, isTrue);
      expect(app.isolatedCapture, isTrue);
      expect(app.capturePreferences, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a later ordinary entrypoint does not inherit fixture state', (
    tester,
  ) async {
    entry.main(arguments);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    entry.main(['--services', '--capture-theme=invalid']);
    await tester.pump();
    final app = tester.widget<entry.CareApp>(find.byType(entry.CareApp));
    expect(app.cleanupFixture, isFalse);
    expect(find.byType(entry.WorkflowPage), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
