import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/retained_workspace.dart';
import 'package:material_system_care/workspace_tabs.dart';
import 'package:material_system_care/localization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('routing cache round trips bounded metadata only', () {
    final tabs = WorkspaceTabs(
      tabs: [
        const WorkspaceTab(id: 'cleanup', route: 'cleanup', group: 'Storage'),
      ],
      active: 'cleanup',
      dock: 'bottom',
    );
    final parsed = WorkspaceTabs.parse(tabs.toJson());
    expect(parsed.tabs.single.group, 'Storage');
    expect(parsed.dock, 'bottom');
    expect(parsed.toJson().keys, ['version', 'tabs', 'active', 'dock']);
  });
  test('corrupt routes, duplicates and active identities fail closed', () {
    final json = WorkspaceTabs.initial().toJson();
    expect(
      () => WorkspaceTabs.parse({...json, 'active': 'missing'}),
      throwsFormatException,
    );
    expect(
      () => WorkspaceTabs.parse({
        ...json,
        'tabs': [...json['tabs'], ...json['tabs']],
      }),
      throwsFormatException,
    );
    expect(
      () => WorkspaceTabs.parse({
        ...json,
        'tabs': [
          {
            'id': 'x',
            'route': 'execute-anything',
            'pinned': false,
            'group': '',
          },
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => WorkspaceTabs.parse({...json, 'dock': 'diagonal'}),
      throwsFormatException,
    );
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('material_system_care/window'),
          (_) async => {'maximized': false},
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('material_system_care/window'),
          null,
        );
  });
  testWidgets('tabs retain a live draft and persist activation metadata', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final saved = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: RetainedWorkspace(
          invoke: (method, params) async {
            if (method == 'settings.get') return {};
            saved.add(params);
            return {};
          },
          page: (_, route) => TextField(
            key: ValueKey('draft-$route'),
            decoration: InputDecoration(labelText: route),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('draft-overview')),
      'review remains local',
    );
    await tester.tap(find.text('Open workspace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recoverable cleanup'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('draft-cleanup')), findsOneWidget);
    await tester.tap(find.text('Overview'));
    await tester.pumpAndSettle();
    expect(find.text('review remains local'), findsOneWidget);
    expect(saved.last['key'], 'workspaceTabs');
    final cache = saved.last['value'] as Map<String, dynamic>;
    expect(WorkspaceTabs.parse(cache).active, 'overview');
    expect(cache.toString(), isNot(contains('review remains local')));
    expect(tester.takeException(), isNull);
  });
  for (final language in ['en', 'yue', 'both']) {
    testWidgets(
      'minimum shell at double text scale $language has no framework overflow',
      (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: CopyScope(
                preferences: {'language': language},
                child: child!,
              ),
            ),
            home: RetainedWorkspace(
              invoke: (_, __) async => {},
              page: (_, route) => ListView(children: [Text(route)]),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.byTooltip(
            localizePreferences({'language': language}, 'Workspace help'),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
