import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/storage_analysis.dart';
import 'package:material_system_care/localization.dart';
import 'package:material_system_care/main.dart' as entry;
import 'package:material_system_care/frame_capture.dart';

const root = r'C:\Analysis';
Map<String, dynamic> response({int files = 2, int folders = 1}) => {
  'root': root,
  'scope': 'selected-folder-only',
  'mutationPerformed': false,
  'fileCount': files,
  'totalBytes': files * 10,
  'emptyFolderCount': folders,
  'inaccessible': 0,
  'reparseSkipped': 0,
  'tooDeep': 0,
  'truncated': false,
  'largeFiles': List<dynamic>.generate(
    files > 100 ? 100 : files,
    (i) => {
      'path': '$root\\file-$i.txt',
      'size': 10,
      'modifiedUtc': '2026-10-10T12:30:00.1234567Z',
    },
  ),
  'emptyFolders': List.generate(
    folders > 1000 ? 1000 : folders,
    (i) => '$root\\empty-$i',
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
          child: StorageAnalysisPage(
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
  await tester.ensureVisible(find.textContaining('Analyze folder').first);
  await tester.tap(find.textContaining('Analyze folder').first);
  await tester.pumpAndSettle();
  expect(find.textContaining('Review folder analysis'), findsOneWidget);
  await tester.ensureVisible(find.textContaining('Analyze selected folder'));
  await tester.tap(find.textContaining('Analyze selected folder'));
  await tester.pump();
}

void main() {
  test(
    'analysis parses bounded read-only results and normalizes selected paths',
    () {
      final parsed = StorageAnalysis.parse(response(), r'c:/Analysis/./');
      expect(parsed.root, root);
      expect(parsed.largeFiles.first.size, 10);
      expect(parsed.largeFiles.first.modifiedUtc.isUtc, isTrue);
      expect(parsed.incomplete, isFalse);
      expect(
        normalizeAnalysisPath(r'\\server\share\folder\..'),
        r'\\server\share\',
      );
      final bounded = StorageAnalysis.parse({
        ...response(files: 101, folders: 1001),
        'truncated': true,
        'inaccessible': 2,
        'reparseSkipped': 3,
        'tooDeep': 1,
      }, root);
      expect(bounded.largeFiles.length, 100);
      expect(bounded.emptyFolders.length, 1000);
      expect(bounded.incomplete, isTrue);
      final empty = StorageAnalysis.parse({
        ...response(files: 0),
        'emptyFolders': [root],
      }, root);
      expect(empty.emptyFolders.single, root);
      final driveRoot = response(files: 1, folders: 0);
      driveRoot['root'] = r'C:\';
      driveRoot['largeFiles'][0]['path'] = r'C:\';
      expect(
        () => StorageAnalysis.parse(driveRoot, r'C:\'),
        throwsFormatException,
      );
    },
  );

  final invalid = <String, void Function(Map<String, dynamic>)>{
    'missing root': (v) => v.remove('root'),
    'different root': (v) => v['root'] = r'C:\Elsewhere',
    'wrong scope': (v) => v['scope'] = 'all-drives',
    'mutation true': (v) => v['mutationPerformed'] = true,
    'mutation numeric': (v) => v['mutationPerformed'] = 0,
    'missing traversal flag': (v) => v.remove('truncated'),
    'string traversal flag': (v) => v['truncated'] = 'false',
    'negative count': (v) => v['fileCount'] = -1,
    'fractional count': (v) => v['inaccessible'] = 1.5,
    'missing count': (v) => v.remove('tooDeep'),
    'oversized count': (v) => v['reparseSkipped'] = 20002,
    'unbounded byte total': (v) => v['totalBytes'] = '20',
    'wrong total': (v) => v['totalBytes'] = 19,
    'missing files': (v) => v.remove('largeFiles'),
    'discarded file': (v) => (v['largeFiles'] as List).removeLast(),
    'extra file': (v) =>
        (v['largeFiles'] as List).add((v['largeFiles'] as List).first),
    'invalid row': (v) => (v['largeFiles'] as List)[0] = null,
    'negative size': (v) => v['largeFiles'][0]['size'] = -1,
    'unsorted size': (v) {
      v['largeFiles'][0]['size'] = 5;
      v['totalBytes'] = 15;
    },
    'duplicate file': (v) =>
        v['largeFiles'][1]['path'] = v['largeFiles'][0]['path'],
    'sibling prefix': (v) =>
        v['largeFiles'][0]['path'] = r'C:\Analysis-other\file.txt',
    'dot escape': (v) =>
        v['largeFiles'][0]['path'] = r'C:\Analysis\..\outside.txt',
    'root as file': (v) => v['largeFiles'][0]['path'] = root,
    'device path': (v) =>
        v['largeFiles'][0]['path'] = r'\\?\C:\Analysis\file.txt',
    'control in path': (v) =>
        v['largeFiles'][0]['path'] = '$root\\bad\u0000.txt',
    'oversized path': (v) =>
        v['largeFiles'][0]['path'] = '$root\\${'x' * 1024}',
    'local timestamp': (v) =>
        v['largeFiles'][0]['modifiedUtc'] = '2026-10-10T12:30:00',
    'invalid date': (v) =>
        v['largeFiles'][0]['modifiedUtc'] = '2026-02-30T12:30:00Z',
    'extra fractional precision': (v) =>
        v['largeFiles'][0]['modifiedUtc'] = '2026-10-10T12:30:00.12345678Z',
    'empty folder outside': (v) => v['emptyFolders'][0] = r'D:\outside',
    'missing empty folder': (v) => v['emptyFolders'] = [],
    'file folder overlap': (v) =>
        v['emptyFolders'][0] = v['largeFiles'][0]['path'],
  };
  for (final entry in invalid.entries) {
    test('analysis rejects ${entry.key} without accepting partial rows', () {
      final value = response();
      entry.value(value);
      expect(() => StorageAnalysis.parse(value, root), throwsFormatException);
    });
  }

  testWidgets(
    'analysis requires root review, clears stale results on edits and failures',
    (tester) async {
      var calls = 0;
      await mount(tester, (method, params, {required requestId}) async {
        calls++;
        expect(method, 'storage.analyze');
        expect(params, {'path': root, 'maxEntries': 20000});
        expect(requestId, startsWith('storage-analysis-'));
        if (calls == 2)
          throw StateError('STORAGE_IO: private synthetic detail');
        return response();
      }, pick: () async => root);
      await tester.tap(find.text('Choose folder'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await start(tester);
      await tester.pumpAndSettle();
      expect(find.text('Analyzed folder'), findsOneWidget);
      await tester.enterText(find.byType(TextField), r'C:\Changed');
      await tester.pump();
      expect(find.text('Analyzed folder'), findsNothing);
      await start(tester);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Folder analysis could not complete'),
        findsOneWidget,
      );
      expect(find.textContaining('private synthetic detail'), findsNothing);
      expect(find.text('Analyzed folder'), findsNothing);
    },
  );

  testWidgets(
    'edited root rejects stale completion and cancellation targets one pending read',
    (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      String? invokedId;
      final cancelledIds = <String>[];
      await mount(
        tester,
        (_, __, {required requestId}) {
          invokedId = requestId;
          return pending.future;
        },
        cancel: (id) async {
          cancelledIds.add(id);
          return true;
        },
      );
      await start(tester);
      await tester.enterText(find.byType(TextField), r'C:\Changed');
      await tester.tap(find.text('Cancel scan'));
      await tester.pump();
      expect(cancelledIds, [invokedId]);
      expect(find.text('Cancellation requested…'), findsOneWidget);
      pending.complete(response());
      await tester.pumpAndSettle();
      expect(find.text('Analyzed folder'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  for (final complete in [true, false]) {
    testWidgets(
      'cancel race preserves ${complete ? 'successful result' : 'stopped-waiting evidence'}',
      (tester) async {
        final pending = Completer<Map<String, dynamic>>();
        await mount(tester, (_, __, {required requestId}) => pending.future);
        await start(tester);
        await tester.tap(find.text('Cancel scan'));
        await tester.pump();
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        if (complete) {
          pending.complete(response());
        } else {
          pending.completeError(PlatformException(code: 'ENGINE_CANCELLED'));
        }
        await tester.pumpAndSettle();
        expect(
          find.text('Analyzed folder'),
          complete ? findsOneWidget : findsNothing,
        );
        expect(
          find.textContaining('does not prove that all engine reads'),
          complete ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets('path editing retains its own paging keys', (tester) async {
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
    final scrolling = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final before = scrolling.position.pixels;
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();
    expect(scrolling.position.pixels, before);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      root,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'disposal requests cancellation and safely ignores late completion',
    (tester) async {
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
    },
  );

  for (final reduced in [true, false]) {
    testWidgets(
      'bilingual minimum-size results support repeated paging and path details reduced=$reduced',
      (tester) async {
        await mount(
          tester,
          (_, __, {required requestId}) async =>
              response(files: 100, folders: 30),
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
                w.focusNode?.debugLabel == 'Folder analysis paging',
          ),
        );
        focus.focusNode!.requestFocus();
        await tester.pump();
        final scrolling = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        var previous = scrolling.position.pixels;
        for (var i = 0; i < 4; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
          if (!reduced && i == 0) {
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 40));
            expect(scrolling.position.pixels, greaterThan(previous));
          }
          await tester.pumpAndSettle();
          expect(scrolling.position.pixels, greaterThan(previous));
          previous = scrolling.position.pixels;
        }
        await tester.scrollUntilVisible(
          find.text('file-99.txt'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('file-99.txt'));
        await tester.pumpAndSettle();
        expect(find.text('$root\\file-99.txt'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('empty-29'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('empty-29'));
        await tester.pumpAndSettle();
        expect(find.text('$root\\empty-29'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'long paths and incomplete counts remain readable without raw records',
    (tester) async {
      final longPath =
          '$root\\${List.filled(10, 'long-folder-name').join(r'\')}\\largest-file.txt';
      final value = response(files: 1);
      value['largeFiles'][0]['path'] = longPath;
      value['truncated'] = true;
      value['inaccessible'] = 2;
      value['reparseSkipped'] = 3;
      value['tooDeep'] = 4;
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
      await tester.scrollUntilVisible(
        find.textContaining('Incomplete view:'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Incomplete view:'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('largest-file.txt'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('largest-file.txt'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(longPath));
      final pathWidget = tester.widget<SelectableText>(
        find.byWidgetPredicate(
          (w) => w is SelectableText && w.data == longPath,
        ),
      );
      expect(pathWidget.data, longPath);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid path and cancelled review never invoke analysis', (
    tester,
  ) async {
    var calls = 0;
    await mount(tester, (_, __, {required requestId}) async {
      calls++;
      return response();
    });
    await tester.enterText(find.byType(TextField), 'relative-folder');
    await tester.pump();
    await tester.tap(find.text('Analyze folder'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a full absolute folder path.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), root);
    await tester.pump();
    await tester.tap(find.text('Analyze folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets(
    'Storage navigation opens dedicated analysis without starting a read',
    (tester) async {
      var reads = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(entry.Engine.channel, (call) async {
        if (call.method == 'invoke' &&
            (call.arguments as Map)['method'] == 'storage.analyze')
          reads++;
        return {'ok': true, 'result': <String, dynamic>{}};
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(entry.Engine.channel, null),
      );
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const entry.CareApp(isolatedCapture: true));
      await tester.pumpAndSettle();
      tester
          .widget<NavigationRail>(find.byType(NavigationRail))
          .onDestinationSelected!(1);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analyze folder'));
      await tester.pumpAndSettle();
      expect(find.byType(StorageAnalysisPage), findsOneWidget);
      expect(reads, 0);
    },
  );

  testWidgets(
    'storage capture selector is exclusive and uses isolated preferences',
    (tester) async {
      const args = [
        '--storage-analysis',
        '--capture-frame=C:/unused-analysis.png',
        '--capture-language=both',
        '--capture-theme=dark',
        '--capture-text-scale=2',
        '--capture-motion=reduced',
      ];
      entry.main(args);
      await tester.pump();
      expect(find.byType(FrameCapture), findsOneWidget);
      final context = tester.element(find.byType(StorageAnalysisPage));
      expect(CopyScope.of(context)['language'], 'both');
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(MediaQuery.textScalerOf(context).scale(10), 20);
      await tester.pumpWidget(const SizedBox());
      entry.main([...args, '--packages']);
      await tester.pump();
      expect(find.byType(FrameCapture), findsNothing);
      expect(
        tester
            .widget<entry.CareApp>(find.byType(entry.CareApp))
            .capturePreferences,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
