import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/main.dart';
import 'package:material_system_care/packages.dart';
import 'package:material_system_care/selection_localizations.dart';

List<String> labels(MaterialLocalizations v) => [
  v.copyButtonLabel,
  v.cutButtonLabel,
  v.pasteButtonLabel,
  v.selectAllButtonLabel,
  v.lookUpButtonLabel,
  v.searchWebButtonLabel,
  v.shareButtonLabel,
];

void main() {
  test('seven commands follow wording modes with meaningful reloads', () async {
    const en = [
      'Copy',
      'Cut',
      'Paste',
      'Select all',
      'Look Up',
      'Search Web',
      'Share',
    ];
    const yue = ['複製', '剪下', '貼上', '全選', '查詢', '搜尋網頁', '分享'];
    for (final language in ['en', 'yue', 'both']) {
      final delegate = SelectionLocalizationsDelegate({'language': language});
      final value = await delegate.load(const Locale('en'));
      expect(
        labels(value),
        List.generate(
          7,
          (i) => language == 'en'
              ? en[i]
              : language == 'yue'
              ? yue[i]
              : '${en[i]}\n${yue[i]}',
        ),
      );
      expect(
        value.cancelButtonLabel,
        const DefaultMaterialLocalizations().cancelButtonLabel,
      );
      expect(
        delegate.shouldReload(
          SelectionLocalizationsDelegate({
            'language': language,
            'theme': 'dark',
          }),
        ),
        isFalse,
      );
    }
    expect(
      SelectionLocalizationsDelegate({
        'language': 'yue',
      }).shouldReload(SelectionLocalizationsDelegate({'language': 'en'})),
      isTrue,
    );
    final map = <String, String>{'Copy': 'Duplicate'};
    final delegate = SelectionLocalizationsDelegate({'privateVocabulary': map});
    map['Copy'] = 'Changed';
    expect(
      (await delegate.load(const Locale('en'))).copyButtonLabel,
      'Duplicate',
    );
    expect(
      delegate.shouldReload(
        SelectionLocalizationsDelegate({'privateVocabulary': map}),
      ),
      isTrue,
    );
  });

  testWidgets(
    'Apps default menu updates wording and retains callbacks at minimum size',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var writes = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') writes++;
        if (call.method == 'Clipboard.hasStrings') return {'value': false};
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      messenger.setMockMethodCallHandler(
        Engine.channel,
        (_) async => {'ok': true, 'result': <String, dynamic>{}},
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(Engine.channel, null),
      );
      await tester.pumpWidget(
        const CareApp(
          isolatedCapture: true,
          capturePreferences: {
            'language': 'en',
            'textScale': 2.0,
            'reducedMotion': true,
          },
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<NavigationRail>(find.byType(NavigationRail))
          .onDestinationSelected!(2);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byType(SearchBar),
        180,
        scrollable: find
            .descendant(
              of: find.byType(PackagesPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      final editable = find.byType(EditableText).first;
      await tester.enterText(editable, 'sample query');
      final state = tester.state<EditableTextState>(editable);
      state.widget.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 6,
      );
      await tester.pump();
      expect(state.showToolbar(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsOneWidget);
      tester.widget<Workspace>(find.byType(Workspace)).changed({
        'language': 'both',
        'textScale': 2.0,
        'reducedMotion': true,
      });
      await tester.pumpAndSettle();
      expect(
        MaterialLocalizations.of(tester.element(editable)).copyButtonLabel,
        'Copy\n複製',
      );
      expect(find.text('Copy\n複製'), findsOneWidget);
      expect(find.text('Copy'), findsNothing);
      state.hideToolbar();
      expect(state.showToolbar(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Copy\n複製'), findsOneWidget);
      final rect = tester.getRect(find.text('Copy\n複製'));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(800));
      expect(rect.bottom, lessThanOrEqualTo(600));
      await tester.tap(find.text('Copy\n複製'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(state.widget.controller.text, 'sample query');
      state.widget.controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 6,
      );
      state.showToolbar();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all\n全選'));
      await tester.pumpAndSettle();
      expect(
        state.widget.controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 12),
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('explicit custom command label and callback remain unchanged', (
    tester,
  ) async {
    var invoked = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          SelectionLocalizationsDelegate({'language': 'both'}),
        ],
        home: Scaffold(
          body: AdaptiveTextSelectionToolbar.buttonItems(
            anchors: const TextSelectionToolbarAnchors(
              primaryAnchor: Offset(100, 100),
            ),
            buttonItems: [
              ContextMenuButtonItem(
                type: ContextMenuButtonType.copy,
                label: 'Custom action',
                onPressed: () => invoked = true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Custom action'), findsOneWidget);
    expect(find.text('Copy\n複製'), findsNothing);
    await tester.tap(find.text('Custom action'));
    expect(invoked, isTrue);
  });
}
