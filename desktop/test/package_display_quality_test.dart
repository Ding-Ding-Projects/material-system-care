import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/packages.dart';
import 'package:material_system_care/localization.dart';

Map<String, dynamic> row([Map<String, dynamic> patch = const {}]) => {
  'id': 'registry:user:64:stable',
  'name': 'Valid neighbor',
  'version': '1.0',
  'publisher': 'Publisher',
  'source': 'uninstallRegistry',
  'scope': 'user',
  'canUninstall': false,
  ...patch,
};
List<PackageRecord> parse(List<Map<String, dynamic>> rows) =>
    PackageRecord.parse({'records': rows}, managed: false);

void main() {
  test(
    'embedded null display data is discarded without losing stable records',
    () {
      const broken = '12345678901234567890123\u0000x';
      final records = parse([
        row({'name': broken}),
        row({'id': 'registry:user:64:neighbor'}),
      ]);
      expect(records, hasLength(2));
      expect(records.first.id, 'registry:user:64:stable');
      expect(records.first.name, '');
      expect(records.first.nameQuality, PackageDisplayQuality.invalid);
      expect(records.first.canUninstall, isFalse);
      expect(records.first.canUpgrade, isFalse);
      expect(records.last.name, 'Valid neighbor');
      expect(records.last.degraded, isFalse);
      final invalid = parse([
        row({'name': null, 'version': 42, 'publisher': 'bad\u0000suffix'}),
      ]).single;
      expect(invalid.nameQuality, PackageDisplayQuality.invalid);
      expect(invalid.versionQuality, PackageDisplayQuality.invalid);
      expect(invalid.publisherQuality, PackageDisplayQuality.invalid);
      expect(invalid.version, isNull);
      expect(invalid.publisher, isNull);
    },
  );
  test(
    'identity source scope and flags remain strict despite fallback display',
    () {
      for (final patch in [
        {'id': 'bad\u0000id'},
        {'id': 'appx:wrong'},
        {'source': 'other'},
        {'scope': 'other'},
        {'canUninstall': true},
        {'canUninstall': 0},
        {'canUpgrade': true},
      ]) {
        expect(
          () => parse([
            row({...patch, 'name': null}),
          ]),
          throwsFormatException,
        );
      }
      expect(
        () => PackageRecord.parse({
          'available': true,
          'records': [
            {
              'id': 'winget:Publisher.Tool',
              'packageId': 'Publisher.Tool',
              'name': 'Publisher.Tool\u0000x',
              'source': 'winget',
              'canUninstall': true,
              'canUpgrade': true,
              'updateAvailability': 'not-checked',
            },
          ],
          'completeInstalledInventory': false,
          'updateAvailability': 'not-checked',
          'limitation': 'Exact matches only',
        }, managed: true),
        throwsFormatException,
      );
    },
  );
  testWidgets(
    'localized fallbacks are searchable without raw values or conflated source counts',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const secret = 'invalid\u0000suffix';
      await tester.pumpWidget(
        MaterialApp(
          home: CopyScope(
            preferences: const {'language': 'both'},
            child: PackagesPage(
              invoke: (_, _) async => {
                'records': [
                  row({'name': secret, 'version': secret, 'publisher': secret}),
                  row({'id': 'registry:user:64:neighbor'}),
                ],
                'unavailable': [
                  'source unavailable',
                  'second source unavailable',
                ],
              },
            ),
          ),
        ),
      );
      await tester.tap(find.textContaining('Refresh records'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Display name unavailable'), findsOneWidget);
      expect(find.textContaining('顯示名稱無法提供'), findsOneWidget);
      expect(
        find.textContaining('Records with unavailable display metadata'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Records with unavailable display metadata\n部分顯示資料無法提供嘅記錄: 1',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Some inventory sources could not be read'),
        findsOneWidget,
      );
      expect(find.textContaining(secret), findsNothing);
      final context = tester.element(find.byType(PackagesPage));
      final record = parse([
        row({'name': secret, 'version': secret, 'publisher': secret}),
      ]).single;
      expect(record.searchText(context), contains('顯示名稱無法提供'));
      expect(record.searchText(context), isNot(contains(secret)));
      await tester.enterText(
        find.descendant(
          of: find.byType(SearchBar),
          matching: find.byType(EditableText),
        ),
        'Display name unavailable',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('registry:user:64:stable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('registry:user:64:neighbor')),
        findsNothing,
      );
      expect(find.textContaining('Review uninstall'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
