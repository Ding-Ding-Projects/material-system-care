import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/main.dart';
import 'package:material_system_care/services.dart';

void main() {
  testWidgets('isolated services entry never collects automatically', (
    tester,
  ) async {
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(Engine.channel, (call) async {
      calls.add(call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(Engine.channel, null));
    await tester.pumpWidget(
      const CareApp(startServices: true, isolatedCapture: true),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ServicesPage), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('service singleton is reviewed and filtered without mutation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <String>[];
    var unavailable = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ServicesPage(
          invoke: (method, parameters) async {
            calls.add(method);
            expect(parameters, isEmpty);
            if (unavailable)
              return {'available': false, 'reason': 'private detail'};
            return {
              'available': true,
              'canChange': false,
              'records': {
                'Name': 'ExampleSvc',
                'DisplayName': 'Example service',
                'Status': 'Running',
                'StartType': 'Manual',
              },
            };
          },
        ),
      ),
    );
    expect(calls, isEmpty);
    await tester.tap(find.text('Read services'));
    await tester.pumpAndSettle();
    expect(find.text('Example service'), findsOneWidget);
    await tester.tap(find.text('Example service'));
    await tester.pumpAndSettle();
    expect(find.text('Configured start type: Manual'), findsOneWidget);
    await tester.enterText(find.byType(SearchBar), 'absent');
    await tester.pumpAndSettle();
    expect(find.text('No matching loaded services.'), findsOneWidget);
    await tester.enterText(find.byType(SearchBar), '');
    await tester.pumpAndSettle();
    unavailable = true;
    await tester.tap(find.text('Read services'));
    await tester.pumpAndSettle();
    expect(find.text('Example service'), findsNothing);
    expect(find.textContaining('private detail'), findsNothing);
    expect(calls, ['services.list', 'services.list']);
  });

  testWidgets('duplicate identities reject the entire response', (
    tester,
  ) async {
    final row = {
      'Name': 'Same',
      'DisplayName': 'Example',
      'Status': 'Stopped',
      'StartType': 'Disabled',
    };
    await tester.pumpWidget(
      MaterialApp(
        home: ServicesPage(
          invoke: (_, __) async => {
            'available': true,
            'canChange': false,
            'records': [row, row],
          },
        ),
      ),
    );
    await tester.tap(find.text('Read services'));
    await tester.pumpAndSettle();
    expect(find.text('Example'), findsNothing);
    expect(
      find.text(
        'Service inventory is unavailable or invalid. No service was changed.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('late service result is ignored after disposal', (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(home: ServicesPage(invoke: (_, __) => pending.future)),
    );
    await tester.tap(find.text('Read services'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete({'available': true, 'canChange': false, 'records': []});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
