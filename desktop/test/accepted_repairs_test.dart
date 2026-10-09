import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/main.dart';
import 'package:material_system_care/settings.dart';
import 'package:material_system_care/wording_cache.dart';
import 'package:material_system_care/localization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('CACHE05 failed staged write preserves old bytes and load', () async {
    final dir = await Directory.systemTemp.createTemp('care-cache-test-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/cache.json');
    const old = '{"schemaVersion":1,"entries":{"Alpha":"Beta"}}';
    await file.writeAsString(old);
    final cache = WordingCache(
      file,
      writeTemporary: (temp, text) async {
        await temp.writeAsString('partial');
        throw const FileSystemException('Injected write fault');
      },
    );
    await expectLater(
      cache.replace('{"schemaVersion":1,"entries":{"Alpha":"Gamma"}}'),
      throwsA(isA<FileSystemException>()),
    );
    expect(await file.readAsString(), old);
    expect((await WordingCache(file).load())['Alpha'], 'Beta');
    expect(await dir.list().length, 1);
  });
  test(
    'CACHE05 failed commit preserves old bytes; successful commit replaces',
    () async {
      final dir = await Directory.systemTemp.createTemp('care-cache-test-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/cache.json');
      const old = '{"schemaVersion":1,"entries":{"Alpha":"Beta"}}';
      const next = '{"schemaVersion":1,"entries":{"Alpha":"Gamma"}}';
      await file.writeAsString(old);
      await expectLater(
        WordingCache(
          file,
          beforeReplace: () async =>
              throw const FileSystemException('Injected commit fault'),
        ).replace(next),
        throwsA(isA<FileSystemException>()),
      );
      expect(await file.readAsString(), old);
      await WordingCache(file).replace(next);
      expect(await file.readAsString(), next);
      expect(await dir.list().length, 1);
    },
  );
  testWidgets('SETTINGS01 retry reads again without saving defaults', (
    tester,
  ) async {
    var reads = 0;
    var writes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsPanel(
            invoke: (method, params) async {
              if (method == 'settings.get') {
                reads++;
                throw StateError('Offline fixture');
              }
              writes++;
              return {};
            },
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(writes, 0);
    await tester.tap(find.text('Retry loading'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(writes, 0);
  });
  testWidgets(
    'WORDING02 initial overview restores local cache even engine unavailable',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('care-startup-test-');
        addTearDown(() => dir.delete(recursive: true));
        final cache = WordingCache(File('${dir.path}/cache.json'));
        await cache.replace(
          '{"schemaVersion":1,"entries":{"Overview":"Summary"}}',
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              Engine.channel,
              (call) async => throw MissingPluginException(),
            );
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(Engine.channel, null),
        );
        await tester.pumpWidget(CareApp(wordingCache: cache));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('Summary'), findsWidgets);
    },
  );
  test('ACCESSIBILITY04 custom scale composes platform output', () {
    const base = TextScaler.linear(2);
    expect(const ComposedTextScaler(base, 1).scale(16), 32);
    expect(const ComposedTextScaler(base, 1.5).scale(16), 48);
  });
  testWidgets(
    'FACTS03 scalar facts and single-pass replacement stay separate',
    (tester) async {
      expect(factualValue(true), 'true');
      expect(factualValue(null), 'null');
      await tester.pumpWidget(
        MaterialApp(
          home: CopyScope(
            preferences: {
              'privateVocabulary': {
                'true': 'changed',
                'Alpha': 'Beta',
                'Beta': 'Gamma',
              },
            },
            child: Builder(
              builder: (context) => Column(
                children: [
                  Text(factualValue(true)),
                  Text(localize(context, 'Alpha')),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('true'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsNothing);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets('RESPONSIVE 800x600 status composition scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            Engine.channel,
            (call) async => throw MissingPluginException(),
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(Engine.channel, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(800, 600),
              textScaler: TextScaler.linear(scale),
            ),
            child: CopyScope(
              preferences: const {},
              child: Workspace(settings: const {}, changed: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('0 records · 0 selected'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('0 records · 0 selected'), findsOneWidget);
    });
  }
}
