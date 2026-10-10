import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/main.dart';
import 'package:material_system_care/localization.dart';

void main() {
  testWidgets('inspection titles stay within toolbar across display tuples', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(800, 600), const Size(1280, 900)]) {
      tester.view.physicalSize = size;
      for (final language in ['en', 'yue', 'both']) {
        for (final theme in ['light', 'dark']) {
          for (final scale in [1.0, 1.25, 1.5, 2.0]) {
            final prefs = {
              'language': language,
              'theme': theme,
              'textScale': scale,
              'reducedMotion': true,
            };
            final pages = <String, CareApp>{
              'Startup': CareApp(
                startStartup: true,
                isolatedCapture: true,
                capturePreferences: prefs,
              ),
              'Services': CareApp(
                startServices: true,
                isolatedCapture: true,
                capturePreferences: prefs,
              ),
              'Scheduled tasks': CareApp(
                startScheduledTasks: true,
                isolatedCapture: true,
                capturePreferences: prefs,
              ),
              'Processes': CareApp(
                startProcesses: true,
                isolatedCapture: true,
                capturePreferences: prefs,
              ),
              'File use': CareApp(
                startFileUse: true,
                isolatedCapture: true,
                capturePreferences: prefs,
              ),
              'Blue-screen diagnostics': CareApp(
                startDiagnostics: true,
                isolatedCapture: true,
                capturePreferences: prefs,
              ),
            };
            for (final entry in pages.entries) {
              await tester.pumpWidget(const SizedBox());
              await tester.pumpWidget(entry.value);
              await tester.pumpAndSettle();
              final context = tester.element(find.byType(AppBar));
              final label = localize(context, entry.key);
              final title = tester.getRect(
                find.descendant(
                  of: find.byType(AppBar),
                  matching: find.text(label),
                ),
              );
              final bar = tester.getRect(find.byType(AppBar));
              final reason = '${entry.key} $size $language $theme $scale';
              expect(title.top, greaterThanOrEqualTo(bar.top), reason: reason);
              expect(
                title.bottom,
                lessThanOrEqualTo(bar.bottom),
                reason: reason,
              );
              expect(
                title.left,
                greaterThanOrEqualTo(bar.left),
                reason: reason,
              );
              expect(title.right, lessThanOrEqualTo(bar.right), reason: reason);
              expect(tester.takeException(), isNull, reason: reason);
            }
          }
        }
      }
    }
  });
  testWidgets('bilingual enlarged service selection fits its field', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const CareApp(
        startServices: true,
        isolatedCapture: true,
        capturePreferences: {
          'language': 'both',
          'theme': 'dark',
          'textScale': 2.0,
          'reducedMotion': true,
        },
      ),
    );
    await tester.pumpAndSettle();
    final title = tester.renderObject<RenderParagraph>(
      find.text('Services\n服務'),
    );
    expect(
      tester.getRect(find.text('Services\n服務')).top,
      greaterThanOrEqualTo(0),
    );
    expect(
      title.size.height,
      greaterThanOrEqualTo(title.getMaxIntrinsicHeight(title.size.width)),
    );
    await tester.scrollUntilVisible(
      find.byType(DropdownButtonFormField<String>),
      180,
    );
    await tester.pumpAndSettle();
    final field = tester.getRect(find.byType(DropdownButtonFormField<String>));
    final value = tester.getRect(find.text('All states\n所有狀態'));
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('All states\n所有狀態'),
    );
    expect(
      paragraph.size.height,
      greaterThanOrEqualTo(
        paragraph.getMaxIntrinsicHeight(paragraph.size.width),
      ),
    );
    expect(value.bottom, lessThanOrEqualTo(field.bottom));
    expect(value.top, greaterThanOrEqualTo(field.top));
    expect(tester.takeException(), isNull);
  });
}
