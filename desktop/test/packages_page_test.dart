import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/packages.dart';
import 'package:material_system_care/localization.dart';

Map<String, dynamic> package({bool canUpgrade = true}) => {
  'id': 'winget:Publisher.Tool',
  'name': 'Publisher.Tool',
  'packageId': 'Publisher.Tool',
  'version': '1.2',
  'source': 'winget',
  'canUpgrade': canUpgrade,
  'canUninstall': true,
  'updateAvailability': 'not-checked',
};
Map<String, dynamic> inventory([List<Map<String, dynamic>>? rows]) => {
  'available': true,
  'records': rows ?? [package()],
  'completeInstalledInventory': false,
  'updateAvailability': 'not-checked',
  'limitation': 'Only installed matches are listed.',
};
Future<void> mount(
  WidgetTester tester,
  PackageInvoke invoke, {
  bool bilingual = false,
}) async {
  tester.view.physicalSize = const Size(1280, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: CopyScope(
        preferences: {'language': bilingual ? 'both' : 'en'},
        child: PackagesPage(invoke: invoke),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> selectManaged(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<bool>));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('WinGet matches').last);
  await tester.pumpAndSettle();
}

Future<void> discover(WidgetTester tester) async {
  await tester.tap(find.textContaining('Discover WinGet packages'));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Confirm selected action'));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'managed identities and capability fields are validated as one inventory',
    () {
      expect(
        PackageRecord.parse(inventory(), managed: true).single.packageId,
        'Publisher.Tool',
      );
      for (final patch in <Map<String, dynamic>>[
        {'id': 'winget:Other.Tool'},
        {'source': 'private'},
        {'canUpgrade': 'true'},
        {'canUninstall': 1},
        {'packageId': '--all'},
        {'updateAvailability': 'available'},
      ]) {
        expect(
          () => PackageRecord.parse(
            inventory([
              {...package(), ...patch},
            ]),
            managed: true,
          ),
          throwsFormatException,
        );
      }
      expect(
        () => PackageRecord.parse(
          inventory([
            package(),
            {
              ...package(),
              'id': 'winget:publisher.tool',
              'name': 'publisher.tool',
              'packageId': 'publisher.tool',
            },
          ]),
          managed: true,
        ),
        throwsFormatException,
      );
      expect(
        () => PackageRecord.parse({
          ...inventory(),
          'completeInstalledInventory': true,
        }, managed: true),
        throwsFormatException,
      );
    },
  );

  test('general inventory never accepts a package mutation capability', () {
    final row = {
      'id': 'registry:user:64:a',
      'name': 'Example',
      'version': '',
      'source': 'uninstallRegistry',
      'scope': 'user',
      'canUninstall': false,
    };
    final record = PackageRecord.parse({
      'records': [row],
    }, managed: false).single;
    expect(record.version, isNull);
    expect(record.packageId, isNull);
    expect(
      () => PackageRecord.parse({
        'records': [
          {...row, 'canUninstall': true},
        ],
      }, managed: false),
      throwsFormatException,
    );
  });

  testWidgets('discovery and a cancelled action require independent reviews', (
    tester,
  ) async {
    final calls = <String>[];
    await mount(tester, (method, params) async {
      calls.add(method);
      return inventory();
    });
    expect(calls, isEmpty);
    await selectManaged(tester);
    await tester.tap(find.text('Discover WinGet packages'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    await discover(tester);
    expect(calls, ['apps.managed']);
    await tester.tap(find.text('Review uninstall'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('does not create a rollback copy'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, ['apps.managed']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exact action success refreshes without forwarding row data', (
    tester,
  ) async {
    final requests = <Map<String, dynamic>>[];
    final calls = <String>[];
    await mount(tester, (method, params) async {
      calls.add(method);
      if (method == 'apps.managed') return inventory();
      requests.add(params);
      return {
        'completed': true,
        'packageId': 'Publisher.Tool',
        'exitCode': 0,
        'restartInitiated': false,
      };
    });
    await selectManaged(tester);
    await discover(tester);
    await tester.tap(find.text('Review upgrade'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm selected action'));
    await tester.pumpAndSettle();
    expect(requests.single, {'packageId': 'Publisher.Tool', 'confirmed': true});
    expect(calls, ['apps.managed', 'apps.upgrade', 'apps.managed']);
    expect(
      find.textContaining('Selected package operation completed'),
      findsOneWidget,
    );
  });

  testWidgets('mismatched completion and failed refresh remove stale actions', (
    tester,
  ) async {
    var reads = 0, mutations = 0;
    await mount(tester, (method, params) async {
      if (method == 'apps.managed') {
        if (++reads > 1)
          return {'available': false, 'records': [], 'reason': 'Unavailable'};
        return inventory();
      }
      mutations++;
      return {
        'completed': true,
        'packageId': 'Other.Tool',
        'exitCode': 0,
        'restartInitiated': false,
      };
    });
    await selectManaged(tester);
    await discover(tester);
    await tester.tap(find.text('Review upgrade'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm selected action'));
    await tester.pumpAndSettle();
    expect(mutations, 1);
    expect(reads, 2);
    expect(find.text('Review upgrade'), findsNothing);
    expect(
      find.textContaining('Package completion was not confirmed'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Selected package operation completed'),
      findsNothing,
    );
  });

  testWidgets('successful empty inventory differs from unavailable inventory', (
    tester,
  ) async {
    var available = true;
    await mount(
      tester,
      (method, params) async => available
          ? inventory([])
          : {'available': false, 'records': [], 'reason': 'Unavailable'},
    );
    await selectManaged(tester);
    await discover(tester);
    expect(
      find.text('No application records match the current filter.'),
      findsOneWidget,
    );
    available = false;
    await discover(tester);
    expect(
      find.text('No application records match the current filter.'),
      findsNothing,
    );
    expect(
      find.textContaining('WinGet discovery is unavailable'),
      findsOneWidget,
    );
  });

  testWidgets('disabled capability remains absent and feedback is bilingual', (
    tester,
  ) async {
    await mount(
      tester,
      (method, params) async => inventory([package(canUpgrade: false)]),
      bilingual: true,
    );
    await selectManaged(tester);
    await discover(tester);
    expect(find.textContaining('Review upgrade'), findsNothing);
    expect(find.textContaining('覆核移除'), findsOneWidget);
    expect(find.textContaining('已重新讀取應用程式記錄'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('valid unavailable causes remain distinct from malformed records', (
    tester,
  ) async {
    var cause = 'WinGet is not installed for the current user.';
    await mount(
      tester,
      (method, params) async => {
        'available': false,
        'records': [],
        'reason': cause,
      },
      bilingual: true,
    );
    await selectManaged(tester);
    await discover(tester);
    expect(find.textContaining('目前使用者未安裝 WinGet'), findsOneWidget);
    cause =
        'WinGet discovery did not complete. Check its installation, source availability and previously accepted source agreements. No source configuration was changed.';
    await discover(tester);
    expect(find.textContaining('來源可用性'), findsOneWidget);
    expect(find.textContaining('目前使用者未安裝 WinGet'), findsNothing);
    cause = '';
    await discover(tester);
    expect(
      find.textContaining('Application records are unavailable or invalid'),
      findsOneWidget,
    );
    expect(find.textContaining('Review upgrade'), findsNothing);
  });

  testWidgets('contradictory completion responses do not claim success', (
    tester,
  ) async {
    var completed = true;
    await mount(
      tester,
      (method, params) async => method == 'apps.managed'
          ? inventory()
          : {
              'packageId': 'Publisher.Tool',
              'completed': completed,
              'exitCode': completed ? 9 : 0,
              'restartInitiated': false,
            },
    );
    await selectManaged(tester);
    await discover(tester);
    for (final flag in [true, false]) {
      completed = flag;
      await tester.tap(find.text('Review upgrade'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm selected action'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Package completion was not confirmed'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Selected package operation completed'),
        findsNothing,
      );
    }
  });

  testWidgets('disposed discovery does not start a follow-on action', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    var calls = 0;
    await mount(tester, (method, params) {
      calls++;
      return pending.future;
    });
    await selectManaged(tester);
    await tester.tap(find.text('Discover WinGet packages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm selected action'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete(inventory());
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
}
