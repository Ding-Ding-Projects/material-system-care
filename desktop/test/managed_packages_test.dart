import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'managed discovery is explicit and exact package actions require review',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final methods = <String>[];
      var unavailable = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(Engine.channel, (call) async {
            final method = call.arguments['method'] as String;
            methods.add(method);
            return {
              'ok': true,
              'result': method == 'apps.managed' && unavailable
                  ? {
                      'available': false,
                      'reason': 'Discovery unavailable for this account.',
                    }
                  : method == 'apps.managed'
                  ? {
                      'available': true,
                      'records': [
                        {
                          'id': 'winget:Publisher.Tool',
                          'name': 'Publisher.Tool',
                          'packageId': 'Publisher.Tool',
                          'version': '1.2',
                          'source': 'winget',
                          'updateAvailability': 'not-checked',
                        },
                      ],
                    }
                  : {'records': <dynamic>[]},
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(Engine.channel, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WorkflowPage(index: 2, title: 'Apps')),
        ),
      );
      await tester.pumpAndSettle();
      expect(methods, ['apps.list']);
      await tester.tap(find.text('Discover WinGet packages'));
      await tester.pumpAndSettle();
      expect(find.textContaining('WinGet may contact'), findsOneWidget);
      expect(methods, ['apps.list']);
      await tester.tap(find.text('Confirm selected action'));
      await tester.pumpAndSettle();
      expect(methods, ['apps.list', 'apps.managed']);
      expect(find.text('Publisher.Tool'), findsOneWidget);
      await tester.tap(find.byTooltip('Record actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upgrade selected app'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Target: Publisher.Tool'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(methods, ['apps.list', 'apps.managed']);
      expect(tester.takeException(), isNull);
      // A failed refresh must not leave stale actionable package rows behind.
      unavailable = true;
      await tester.tap(find.text('Discover WinGet packages'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm selected action'));
      await tester.pumpAndSettle();
      expect(find.text('Publisher.Tool'), findsNothing);
      expect(find.byTooltip('Record actions'), findsNothing);
      expect(
        find.textContaining('Discovery unavailable for this account.'),
        findsWidgets,
      );
      expect(methods, ['apps.list', 'apps.managed', 'apps.managed']);
      expect(tester.takeException(), isNull);
    },
  );
}
