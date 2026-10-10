import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/duplicate_analysis.dart';
import 'package:material_system_care/storage_analysis.dart'
    show StorageAnalysisInvoke;
import 'package:material_system_care/localization.dart';
import 'package:material_system_care/main.dart' as entry;
import 'package:material_system_care/frame_capture.dart';

const root = r'C:\Duplicates';
Map<String, dynamic> response({int groups = 1, int paths = 2}) => {
  'root': root,
  'mutationPerformed': false,
  'hashedBytes': groups * paths * 10,
  'budgetReached': false,
  'changedOrUnavailable': 0,
  'inaccessible': 0,
  'reparseSkipped': 0,
  'tooDeep': 0,
  'truncated': false,
  'groups': List<dynamic>.generate(
    groups,
    (i) => <String, dynamic>{
      'size': 10,
      'totalMatchingFiles': paths,
      'pathsTruncated': paths > 20,
      'reclaimableBytes': 10 * (paths - 1),
      'verification': 'sha256-and-byte-comparison',
      'paths': List<dynamic>.generate(
        paths > 20 ? 20 : paths,
        (j) => '$root\\group-$i\\file-$j.txt',
      ),
    },
  ),
};

Future<void> mount(
  WidgetTester tester,
  StorageAnalysisInvoke invoke, {
  Future<bool> Function(String)? cancel,
  Future<String?> Function()? pick,
  bool bilingual = false,
  bool reduced = true,
  Size size = const Size(1200, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: CopyScope(
        preferences: {'language': bilingual ? 'both' : 'en'},
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(bilingual ? 2 : 1),
            disableAnimations: reduced,
          ),
          child: DuplicateAnalysisPage(
            invoke: invoke,
            cancel: cancel ?? (_) async => true,
            pickFolder: pick,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> start(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byType(TextField),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.enterText(find.byType(TextField), root);
  await tester.pump();
  await tester.ensureVisible(find.textContaining('Analyze duplicates').first);
  await tester.tap(find.textContaining('Analyze duplicates').first);
  await tester.pumpAndSettle();
  expect(find.textContaining('Review duplicate analysis'), findsOneWidget);
  await tester.ensureVisible(find.textContaining('Find exact duplicates'));
  await tester.tap(find.textContaining('Find exact duplicates'));
  await tester.pump();
}

void main() {
  test(
    'duplicate parser preserves verified counts, estimates and empty results',
    () {
      final parsed = DuplicateAnalysis.parse(response(paths: 21), root);
      expect(parsed.groups.single.paths.length, 20);
      expect(parsed.potentialBytes, 200);
      expect(parsed.incomplete, isFalse);
      expect(
        DuplicateAnalysis.parse(response(groups: 0), root).groups,
        isEmpty,
      );
      expect(
        DuplicateAnalysis.parse({...response(), 'tooDeep': 1}, root).incomplete,
        isTrue,
      );
    },
  );
  final negatives = <String, void Function(Map<String, dynamic>)>{
    'missing root': (v) => v.remove('root'),
    'wrong root': (v) => v['root'] = r'C:\Other',
    'mutation enabled': (v) => v['mutationPerformed'] = true,
    'mutation numeric': (v) => v['mutationPerformed'] = 0,
    'missing depth count': (v) => v.remove('tooDeep'),
    'negative depth': (v) => v['tooDeep'] = -1,
    'string flag': (v) => v['truncated'] = 'false',
    'numeric budget': (v) => v['budgetReached'] = 1,
    'fractional count': (v) => v['inaccessible'] = 0.5,
    'missing count': (v) => v.remove('reparseSkipped'),
    'excessive count': (v) => v['changedOrUnavailable'] = 100000001,
    'excessive hashed bytes': (v) => v['hashedBytes'] = 536870913,
    'missing groups': (v) => v.remove('groups'),
    'too many groups': (v) => v['groups'] = response(groups: 101)['groups'],
    'malformed row': (v) => v['groups'][0] = null,
    'unverified group': (v) => v['groups'][0]['verification'] = 'sha256-only',
    'negative size': (v) => v['groups'][0]['size'] = -1,
    'wrong potential estimate': (v) => v['groups'][0]['reclaimableBytes'] = 100,
    'single match': (v) => v['groups'][0]['totalMatchingFiles'] = 1,
    'too many matches': (v) => v['groups'][0]['totalMatchingFiles'] = 10001,
    'missing path': (v) => v['groups'][0]['paths'].removeLast(),
    'extra path': (v) => v['groups'][0]['paths'].add('$root\\extra.txt'),
    'string truncation flag': (v) => v['groups'][0]['pathsTruncated'] = 'false',
    'inconsistent truncation': (v) => v['groups'][0]['pathsTruncated'] = true,
    'duplicate path': (v) =>
        v['groups'][0]['paths'][1] = v['groups'][0]['paths'][0],
    'sibling prefix path': (v) =>
        v['groups'][0]['paths'][0] = r'C:\Duplicates-other\a',
    'root path': (v) => v['groups'][0]['paths'][0] = root,
    'escape path': (v) =>
        v['groups'][0]['paths'][0] = r'C:\Duplicates\..\outside',
    'device path': (v) => v['groups'][0]['paths'][0] = r'\\?\C:\Duplicates\a',
    'control path': (v) => v['groups'][0]['paths'][0] = '$root\\a\u0000',
    'long path': (v) => v['groups'][0]['paths'][0] = '$root\\${'x' * 1024}',
    'groups exceed hashed bytes': (v) => v['hashedBytes'] = 1,
  };
  for (final testCase in negatives.entries) {
    test('duplicate parser rejects ${testCase.key}', () {
      final value = response();
      testCase.value(value);
      expect(() => DuplicateAnalysis.parse(value, root), throwsFormatException);
    });
  }
  test(
    'paths are unique across groups and truncated rows retain exact count',
    () {
      final value = response(groups: 2);
      value['groups'][1]['paths'][0] = value['groups'][0]['paths'][0];
      expect(() => DuplicateAnalysis.parse(value, root), throwsFormatException);
      final short = response(paths: 21);
      short['groups'][0]['paths'].removeLast();
      expect(() => DuplicateAnalysis.parse(short, root), throwsFormatException);
    },
  );

  testWidgets('review gates read and root edits discard late response', (
    tester,
  ) async {
    var calls = 0;
    final pending = Completer<Map<String, dynamic>>();
    await mount(tester, (method, params, {required requestId}) {
      calls++;
      expect(method, 'storage.duplicates');
      expect(params, {'path': root, 'maxEntries': 10000, 'maxHashMiB': 512});
      expect(requestId, startsWith('duplicate-analysis-'));
      return pending.future;
    });
    expect(calls, 0);
    await start(tester);
    expect(calls, 1);
    await tester.enterText(find.byType(TextField), r'C:\Changed');
    pending.complete(response());
    await tester.pumpAndSettle();
    expect(find.text('Analyzed folder'), findsNothing);
  });
  for (final success in [true, false]) {
    testWidgets(
      'duplicate cancellation preserves ${success ? 'completion' : 'stopped wait'}',
      (tester) async {
        final pending = Completer<Map<String, dynamic>>();
        String? request;
        final cancellations = <String>[];
        await mount(
          tester,
          (_, __, {required requestId}) {
            request = requestId;
            return pending.future;
          },
          cancel: (id) async {
            cancellations.add(id);
            return true;
          },
        );
        await start(tester);
        await tester.tap(find.text('Cancel scan'));
        await tester.pump();
        expect(cancellations, [request]);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        if (success) {
          pending.complete(response());
        } else {
          pending.completeError(PlatformException(code: 'ENGINE_CANCELLED'));
        }
        await tester.pumpAndSettle();
        expect(
          find.text('Analyzed folder'),
          success ? findsOneWidget : findsNothing,
        );
        expect(
          find.textContaining('does not prove that all engine reads'),
          success ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'new failure clears prior groups and does not reflect raw exception',
    (tester) async {
      var count = 0;
      await mount(tester, (_, __, {required requestId}) async {
        if (count++ == 0) return response();
        throw StateError('private synthetic data');
      });
      await start(tester);
      await tester.pumpAndSettle();
      expect(find.text('Analyzed folder'), findsOneWidget);
      await start(tester);
      await tester.pumpAndSettle();
      expect(find.text('Analyzed folder'), findsNothing);
      expect(
        find.textContaining('Duplicate analysis could not complete'),
        findsOneWidget,
      );
      expect(find.textContaining('private synthetic data'), findsNothing);
    },
  );
  testWidgets('disposing pending duplicate read cancels exact request', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    final ids = <String>[];
    await mount(
      tester,
      (_, __, {required requestId}) => pending.future,
      cancel: (id) async {
        ids.add(id);
        return true;
      },
    );
    await start(tester);
    await tester.pumpWidget(const SizedBox());
    pending.complete(response());
    await tester.pumpAndSettle();
    expect(ids, hasLength(1));
    expect(tester.takeException(), isNull);
  });
  for (final reduced in [true, false]) {
    testWidgets(
      'bilingual duplicate groups page and expand at minimum size reduced=$reduced',
      (tester) async {
        await mount(
          tester,
          (_, __, {required requestId}) async => response(groups: 60),
          bilingual: true,
          reduced: reduced,
          size: const Size(800, 600),
        );
        await start(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        final focus = tester.widget<Focus>(
          find.byWidgetPredicate(
            (w) =>
                w is Focus &&
                w.focusNode?.debugLabel == 'Duplicate analysis paging',
          ),
        );
        focus.focusNode!.requestFocus();
        await tester.pump();
        final scroller = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        var before = scroller.position.pixels;
        for (var i = 0; i < 3; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
          if (!reduced && i == 0) {
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 40));
            expect(scroller.position.pixels, greaterThan(before));
          }
          await tester.pumpAndSettle();
          expect(scroller.position.pixels, greaterThan(before));
          before = scroller.position.pixels;
        }
        final last = find.text('Duplicate group\n重複檔案組別 60');
        await tester.scrollUntilVisible(
          last,
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(last);
        await tester.pumpAndSettle();
        final tile = find.ancestor(
          of: last,
          matching: find.byType(ExpansionTile),
        );
        final collapsed = tester.getSize(tile).height;
        await tester.tap(last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        final middle = tester.getSize(tile).height;
        await tester.pumpAndSettle();
        final expanded = tester.getSize(tile).height;
        expect(expanded, greaterThan(collapsed));
        expect(middle, reduced ? expanded : lessThan(expanded));
        if (!reduced) expect(middle, greaterThan(collapsed));
        expect(find.text('$root\\group-59\\file-0.txt'), findsOneWidget);
        await tester.ensureVisible(last);
        await tester.tap(last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        final reversing = tester.getSize(tile).height;
        await tester.pumpAndSettle();
        expect(reversing, reduced ? collapsed : greaterThan(collapsed));
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
  testWidgets('empty and incomplete duplicate views remain explicit', (
    tester,
  ) async {
    await mount(
      tester,
      (_, __, {required requestId}) async => {
        ...response(groups: 0),
        'tooDeep': 1,
        'budgetReached': true,
        'changedOrUnavailable': 3,
        'truncated': true,
      },
    );
    await start(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Incomplete duplicate view: some comparisons may be missing.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.textContaining('No exact duplicate groups'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('No exact duplicate groups'), findsOneWidget);
    expect(find.text('Folders beyond depth limit: 1'), findsOneWidget);
  });
  testWidgets(
    'picked root still needs review and cancelled review starts no read',
    (tester) async {
      var calls = 0;
      await mount(tester, (_, __, {required requestId}) async {
        calls++;
        return response();
      }, pick: () async => root);
      await tester.tap(find.text('Choose folder'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('Analyze duplicates'));
      await tester.pumpAndSettle();
      expect(find.text('Review duplicate analysis'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 0);
    },
  );
  testWidgets(
    'long duplicate paths remain selectable at bilingual minimum size',
    (tester) async {
      final value = response();
      final longPath =
          '$root\\${List.filled(12, 'long-folder-name').join(r'\')}\\file.txt';
      value['groups'][0]['paths'][0] = longPath;
      await mount(
        tester,
        (_, __, {required requestId}) async => value,
        bilingual: true,
        size: const Size(800, 600),
      );
      await start(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      final title = find.text('Duplicate group\n重複檔案組別 1');
      await tester.scrollUntilVisible(
        title,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(title);
      await tester.pumpAndSettle();
      await tester.tap(title);
      await tester.pumpAndSettle();
      final path = find.byWidgetPredicate(
        (w) => w is SelectableText && w.data == longPath,
      );
      expect(path, findsOneWidget);
      await tester.ensureVisible(path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('duplicate root text retains editing keys', (tester) async {
    await mount(
      tester,
      (_, __, {required requestId}) async => response(),
      bilingual: true,
      size: const Size(800, 600),
    );
    await tester.scrollUntilVisible(
      find.byType(TextField),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField), root);
    await tester.pumpAndSettle();
    final scroller = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final before = scroller.position.pixels;
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(scroller.position.pixels, before);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  testWidgets('duplicate capture destination remains exclusive and isolated', (
    tester,
  ) async {
    const args = [
      '--duplicate-analysis',
      '--capture-frame=C:/unused-duplicates.png',
      '--capture-language=both',
      '--capture-theme=dark',
      '--capture-text-scale=2',
      '--capture-motion=reduced',
    ];
    entry.main(args);
    await tester.pump();
    expect(find.byType(FrameCapture), findsOneWidget);
    expect(find.byType(DuplicateAnalysisPage), findsOneWidget);
    final context = tester.element(find.byType(DuplicateAnalysisPage));
    expect(CopyScope.of(context)['language'], 'both');
    expect(MediaQuery.textScalerOf(context).scale(10), 20);
    await tester.pumpWidget(const SizedBox());
    entry.main([...args, '--storage-analysis']);
    await tester.pump();
    expect(find.byType(FrameCapture), findsNothing);
    expect(
      tester
          .widget<entry.CareApp>(find.byType(entry.CareApp))
          .capturePreferences,
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
