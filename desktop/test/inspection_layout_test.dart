import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/main.dart';

void main() {
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
    final title = tester.renderObject<RenderParagraph>(find.text('Services\n服務'));
    expect(title.size.height, greaterThanOrEqualTo(title.getMaxIntrinsicHeight(title.size.width)));
    await tester.scrollUntilVisible(find.byType(DropdownButtonFormField<String>), 180);
    await tester.pumpAndSettle();
    final field = tester.getRect(find.byType(DropdownButtonFormField<String>));
    final value = tester.getRect(find.text('All states\n所有狀態'));
    final paragraph = tester.renderObject<RenderParagraph>(find.text('All states\n所有狀態'));
    expect(paragraph.size.height, greaterThanOrEqualTo(paragraph.getMaxIntrinsicHeight(paragraph.size.width)));
    expect(value.bottom, lessThanOrEqualTo(field.bottom));
    expect(value.top, greaterThanOrEqualTo(field.top));
    expect(tester.takeException(), isNull);
  });
}
