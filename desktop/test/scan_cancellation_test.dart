import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_system_care/main.dart';
import 'package:material_system_care/notifications.dart';

void main() {
  testWidgets(
    'read cancellation targets its request and awaits terminal result',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Notices.instance.value = [];
      var pending = Completer<Object?>();
      String? activeId;
      final cancellations = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(Engine.channel, (call) async {
        if (call.method == 'cancel') {
          cancellations.add(call.arguments as String);
          return true;
        }
        activeId = call.arguments['id'] as String;
        expect(call.arguments['method'], 'storage.analyze');
        return pending.future;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(Engine.channel, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: WorkflowPage(index: 1, title: 'Storage')),
        ),
      );
      await tester.tap(find.text('Analyze folder'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), r'C:\Analysis');
      await tester.pump();
      await tester.tap(find.text('Analyze folder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analyze selected folder'));
      await tester.pump();
      expect(activeId, startsWith('storage-analysis-'));
      await tester.tap(find.text('Cancel scan'));
      await tester.pump();
      expect(cancellations, [activeId]);
      expect(find.text('Cancellation requested…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(Notices.instance.value, isEmpty);
      pending.completeError(
        PlatformException(
          code: 'ENGINE_CANCELLED',
          message: 'Engine operation cancelled',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        find.text(
          'Stopped waiting for analysis. This does not prove that all engine reads have stopped.',
        ),
        findsOneWidget,
      );
      expect(Notices.instance.value.single.kind, 'cancelled');
      expect(find.text('Result received from local engine'), findsNothing);
      expect(tester.takeException(), isNull);
      // A completed result may win the cancellation race. Do not relabel it.
      final firstId = activeId;
      pending = Completer<Object?>();
      await tester.tap(find.text('Analyze folder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analyze selected folder'));
      await tester.pump();
      expect(activeId, isNot(firstId));
      await tester.tap(find.text('Cancel scan'));
      await tester.pump();
      expect(cancellations.last, activeId);
      pending.complete({
        'ok': true,
        'result': {
          'root': r'C:\Analysis',
          'scope': 'selected-folder-only',
          'mutationPerformed': false,
          'fileCount': 0,
          'totalBytes': 0,
          'emptyFolderCount': 0,
          'inaccessible': 0,
          'reparseSkipped': 0,
          'tooDeep': 0,
          'truncated': false,
          'largeFiles': <dynamic>[],
          'emptyFolders': <dynamic>[],
        },
      });
      await tester.pumpAndSettle();
      expect(Notices.instance.value.first.kind, 'success');
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Cancellation requested…'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
