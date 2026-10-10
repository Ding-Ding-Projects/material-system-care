import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/labeled_controls.dart';

void main() {
  testWidgets('bilingual labels retain every line at enlarged narrow widths', (
    tester,
  ) async {
    const label =
        'Filter loaded tasks by name, folder or state\n按名稱、資料夾或狀態篩選已載入工作';
    for (final width in [220.0, 300.0, 752.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: const LabeledSearchBar(
                    label: label,
                    leading: Icon(Icons.search),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(find.text(label));
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(paragraph.getMaxIntrinsicHeight(width)),
      );
      expect(
        tester.getRect(find.byType(SearchBar)).top,
        greaterThanOrEqualTo(tester.getRect(find.text(label)).bottom),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('search input and existing controller remain functional', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LabeledSearchBar(
            label: 'Filter records\n篩選記錄',
            controller: controller,
            onChanged: (value) => changed = value,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'service');
    expect(controller.text, 'service');
    expect(changed, 'service');
    expect(find.text('Filter records\n篩選記錄'), findsOneWidget);
  });
}
