import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          Engine.channel,
          (call) async => throw MissingPluginException(),
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(Engine.channel, null);
  });
  testWidgets(
    'workspace exposes productive navigation and honest pending state',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const CareApp());
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Overview'), findsWidgets);
      expect(find.textContaining('provenance unavailable'), findsOneWidget);
      expect(find.textContaining('not connected'), findsOneWidget);
      expect(find.byType(SearchBar), findsOneWidget);
      await tester.tap(find.text('Tools'));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<int>), findsOneWidget);
      expect(find.text('Calculate SHA-256'), findsOneWidget);
    },
  );
}
