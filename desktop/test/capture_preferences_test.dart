import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/capture_preferences.dart';
import 'package:material_system_care/main.dart';
import 'package:material_system_care/localization.dart';
import 'package:material_system_care/services.dart';

void main() {
  test('capture display controls reject invalid or repeated values', () {
    expect(parseCapturePreferences([]), isEmpty);
    expect(
      parseCapturePreferences([
        '--capture-theme=dark',
        '--capture-language=both',
        '--capture-text-scale=1.5',
        '--capture-motion=reduced',
      ]),
      {
        'theme': 'dark',
        'language': 'both',
        'textScale': 1.5,
        'reducedMotion': true,
      },
    );
    for (final arguments in [
      ['--capture-theme=dark', '--capture-theme=dark'],
      ['--capture-theme=system'],
      ['--capture-theme'],
      ['--capture-language=unknown'],
      ['--capture-text-scale=NaN'],
      ['--capture-text-scale=200'],
      ['--capture-motion=full'],
    ]) {
      expect(parseCapturePreferences(arguments), isNull);
    }
  });
  testWidgets(
    'isolated display tuple applies without settings or record reads',
    (tester) async {
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(Engine.channel, (call) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(Engine.channel, null),
      );
      await tester.pumpWidget(
        CareApp(
          startServices: true,
          isolatedCapture: true,
          capturePreferences: parseCapturePreferences([
            '--capture-theme=dark',
            '--capture-language=yue',
            '--capture-text-scale=2',
            '--capture-motion=reduced',
          ])!,
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(ServicesPage));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(CopyScope.of(context)['language'], 'yue');
      expect(MediaQuery.textScalerOf(context).scale(12), 24);
      expect(MediaQuery.disableAnimationsOf(context), isTrue);
      expect(find.text('檢視本機服務'), findsOneWidget);
      expect(calls, isEmpty);
    },
  );
}
