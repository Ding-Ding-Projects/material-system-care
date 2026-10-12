import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/retained_workspace.dart';
import 'package:material_system_care/workspace_tabs.dart';
import 'package:material_system_care/localization.dart';
import 'package:material_system_care/main.dart';
import 'package:material_system_care/cleanup_workspace.dart';

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
  testWidgets(
    'disposable shell retains fixture scope in the typed cleanup route',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            Engine.channel,
            (_) async => {'ok': true, 'result': {}},
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(Engine.channel, null),
      );
      await tester.pumpWidget(
        const CareApp(
          cleanupFixture: true,
          startWorkspace: true,
          isolatedCapture: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open workspace'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recoverable cleanup'));
      await tester.pumpAndSettle();
      final cleanup = tester.widget<CleanupWorkspace>(
        find.byType(CleanupWorkspace),
      );
      expect(cleanup.fixture, isTrue);
      expect(
        find.textContaining('Disposable cleanup verification only'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'live route state survives every dock position without disposal',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var disposed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: RetainedWorkspace(
            invoke: (_, __) async => {},
            page: (_, route) =>
                DockSentinel(key: ValueKey(route), onDispose: () => disposed++),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final original = tester.state<DockSentinelState>(
        find.byType(DockSentinel),
      );
      await tester.enterText(
        find.byType(TextField).last,
        'keep this exact draft',
      );
      for (final dock in ['right', 'top', 'bottom', 'left']) {
        await tester.tap(find.byTooltip('Dock tabs'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dock $dock'));
        await tester.pumpAndSettle();
        expect(
          identical(
            tester.state<DockSentinelState>(find.byType(DockSentinel)),
            original,
          ),
          isTrue,
          reason: 'State identity at $dock',
        );
        expect(original.controller.text, 'keep this exact draft');
        expect(disposed, 0, reason: 'No route disposal at $dock');
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('only the retained shell claims and releases native chrome', (
    tester,
  ) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('material_system_care/window'),
          (call) async {
            calls.add(call.method);
            return call.method == 'state' ? {'maximized': false} : null;
          },
        );
    await tester.pumpWidget(
      MaterialApp(
        home: RetainedWorkspace(
          invoke: (_, __) async => {},
          page: (_, route) => Text(route),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, contains('claimShell'));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(calls, contains('releaseShell'));
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          Engine.channel,
          (_) async => {'ok': true, 'result': {}},
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(Engine.channel, null),
    );
    await tester.pumpWidget(
      const CareApp(cleanupFixture: true, isolatedCapture: true),
    );
    await tester.pumpAndSettle();
    expect(calls, isNot(contains('claimShell')));
    expect(find.byType(CleanupWorkspace), findsOneWidget);
    await tester.pumpWidget(
      const CareApp(startDiagnostics: true, isolatedCapture: true),
    );
    await tester.pumpAndSettle();
    expect(calls, isNot(contains('claimShell')));
  });
}

class DockSentinel extends StatefulWidget {
  const DockSentinel({super.key, required this.onDispose});
  final VoidCallback onDispose;
  @override
  State<DockSentinel> createState() => DockSentinelState();
}

class DockSentinelState extends State<DockSentinel> {
  final controller = TextEditingController();
  @override
  void dispose() {
    widget.onDispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(controller: controller);
}
