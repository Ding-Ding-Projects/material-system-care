import 'package:flutter/material.dart';
import 'localization.dart';

class Notice {
  const Notice(this.kind, this.operation);
  final String kind;
  final String operation;
}

class Notices extends ValueNotifier<List<Notice>> {
  Notices._() : super([]);
  static final instance = Notices._();
  void add(String kind, String operation) {
    value = [Notice(kind, operation), ...value].take(100).toList();
  }
}

class NotificationPanel extends StatelessWidget {
  const NotificationPanel({super.key});
  @override
  Widget build(BuildContext context) => Drawer(
    child: SafeArea(
      child: ValueListenableBuilder<List<Notice>>(
        valueListenable: Notices.instance,
        builder: (context, items, _) => Column(
          children: [
            ListTile(
              title: UiText('Notifications'),
              trailing: IconButton(
                tooltip: localize(context, 'Close'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(child: UiText('No notifications yet.'))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) => ListTile(
                        leading: Icon(
                          items[i].kind == 'error'
                              ? Icons.error_outline
                              : items[i].kind == 'cancelled'
                              ? Icons.stop_circle_outlined
                              : Icons.check_circle_outline,
                        ),
                        title: UiText(
                          items[i].kind == 'error'
                              ? 'Operation could not complete'
                              : items[i].kind == 'cancelled'
                              ? 'Stopped waiting for scan.'
                              : 'Result received from local engine',
                        ),
                        subtitle: Text(items[i].operation),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

void notifyOperation(BuildContext context, String kind, String operation) {
  Notices.instance.add(kind, operation);
  final preferences = CopyScope.of(context);
  if (kind != 'error' &&
      preferences[kind == 'progress'
              ? 'notificationsProgress'
              : 'notificationsSuccess'] ==
          false)
    return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      width: MediaQuery.sizeOf(context).width.clamp(0, 440) - 32,
      duration: kind == 'error'
          ? const Duration(days: 1)
          : const Duration(seconds: 5),
      showCloseIcon: true,
      content: Semantics(
        liveRegion: true,
        child: UiText(
          kind == 'error'
              ? 'Operation could not complete'
              : kind == 'cancelled'
              ? 'Stopped waiting for scan.'
              : 'Result received from local engine',
        ),
      ),
    ),
  );
}
