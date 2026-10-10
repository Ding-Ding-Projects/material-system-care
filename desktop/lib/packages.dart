import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'inspection_app_bar.dart';
import 'labeled_controls.dart';
import 'localization.dart';
import 'motion.dart';

typedef PackageInvoke =
    Future<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> parameters,
    );

String _text(Object? value, {int limit = 1024}) {
  if (value is! String ||
      value.isEmpty ||
      value.length > limit ||
      value.runes.any((c) => c < 32 || c == 127))
    throw const FormatException();
  return value;
}

String? _optionalText(Object? value, {int limit = 1024}) =>
    value == null || value == '' ? null : _text(value, limit: limit);

enum PackageDisplayQuality { available, notProvided, invalid }

(String?, PackageDisplayQuality) _displayText(
  Object? value,
  int limit, {
  bool mandatory = false,
}) {
  if (!mandatory && (value == null || value == ''))
    return (null, PackageDisplayQuality.notProvided);
  try {
    final text = _text(value, limit: limit);
    if (text.trim().isEmpty) return (null, PackageDisplayQuality.invalid);
    return (text, PackageDisplayQuality.available);
  } on FormatException {
    return (null, PackageDisplayQuality.invalid);
  }
}

class PackageRecord {
  const PackageRecord({
    required this.id,
    required this.name,
    required this.source,
    this.version,
    this.publisher,
    this.scope,
    this.packageId,
    this.canUpgrade = false,
    this.canUninstall = false,
    this.nameQuality = PackageDisplayQuality.available,
    this.versionQuality = PackageDisplayQuality.available,
    this.publisherQuality = PackageDisplayQuality.available,
  });
  final String id, name, source;
  final String? version, publisher, scope, packageId;
  final bool canUpgrade, canUninstall;
  final PackageDisplayQuality nameQuality, versionQuality, publisherQuality;
  bool get degraded => [
    nameQuality,
    versionQuality,
    publisherQuality,
  ].contains(PackageDisplayQuality.invalid);
  String displayName(BuildContext context) =>
      nameQuality == PackageDisplayQuality.invalid
      ? localize(context, 'Display name unavailable')
      : name;
  String displayVersion(BuildContext context) =>
      versionQuality == PackageDisplayQuality.invalid
      ? localize(context, 'Version unavailable')
      : version ?? localize(context, 'Unavailable');
  String? displayPublisher(BuildContext context) =>
      publisherQuality == PackageDisplayQuality.invalid
      ? localize(context, 'Publisher unavailable')
      : publisher;
  String searchText(BuildContext context) =>
      '${displayName(context)} $id ${displayVersion(context)} ${displayPublisher(context) ?? ''}';

  static List<PackageRecord> parse(
    Map<String, dynamic> result, {
    required bool managed,
  }) {
    final raw = result['records'];
    if (raw is! List || raw.length > (managed ? 10000 : 20000))
      throw const FormatException();
    final ids = <String>{};
    if (managed &&
        (result['available'] != true ||
            result['completeInstalledInventory'] != false ||
            result['updateAvailability'] != 'not-checked'))
      throw const FormatException();
    if (managed) _text(result['limitation'], limit: 2048);
    return raw.map((value) {
      if (value is! Map) throw const FormatException();
      final id = _text(value['id'], limit: 2048);
      final source = _text(value['source'], limit: 64);
      if (!ids.add(managed ? id.toLowerCase() : id))
        throw const FormatException();
      if (managed) {
        final name = _text(value['name']);
        final packageId = _text(value['packageId'], limit: 256);
        if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._+-]*$').hasMatch(packageId) ||
            id != 'winget:$packageId' ||
            name != packageId ||
            source != 'winget' ||
            value['canUpgrade'] is! bool ||
            value['canUninstall'] is! bool ||
            value['updateAvailability'] != 'not-checked')
          throw const FormatException();
        return PackageRecord(
          id: id,
          name: name,
          source: source,
          packageId: packageId,
          version: _optionalText(value['version'], limit: 256),
          canUpgrade: value['canUpgrade'] as bool,
          canUninstall: value['canUninstall'] as bool,
        );
      }
      final scope = _text(value['scope'], limit: 16);
      if ((source != 'appx' && source != 'uninstallRegistry') ||
          !id.startsWith(source == 'appx' ? 'appx:' : 'registry:') ||
          (scope != 'user' && scope != 'machine') ||
          value['canUninstall'] != false ||
          (value.containsKey('canUpgrade') && value['canUpgrade'] != false))
        throw const FormatException();
      final (name, nameQuality) = _displayText(
        value['name'],
        1024,
        mandatory: true,
      );
      final (version, versionQuality) = _displayText(value['version'], 256);
      final (publisher, publisherQuality) = _displayText(
        value['publisher'],
        2048,
      );
      return PackageRecord(
        id: id,
        name: name ?? '',
        source: source,
        scope: scope,
        version: version,
        publisher: publisher,
        nameQuality: nameQuality,
        versionQuality: versionQuality,
        publisherQuality: publisherQuality,
      );
    }).toList();
  }
}

class PackagesPage extends StatefulWidget {
  const PackagesPage({super.key, required this.invoke});
  final PackageInvoke invoke;
  @override
  State<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<PackagesPage> {
  final _scroll = ScrollController();
  final _resultsFocus = FocusNode(debugLabel: 'Package results');

  @override
  void dispose() {
    _resultsFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  KeyEventResult _scrollKey(FocusNode node, KeyEvent event) {
    if (FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<EditableText>() !=
        null)
      return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent)
      return KeyEventResult.ignored;
    if (!_scroll.hasClients) return KeyEventResult.ignored;
    final position = _scroll.position;
    final step = position.viewportDimension * 0.8;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.pageDown && key != LogicalKeyboardKey.pageUp)
      return KeyEventResult.ignored;
    final target =
        (position.pixels + (key == LogicalKeyboardKey.pageDown ? step : -step))
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
    }
    return KeyEventResult.handled;
  }

  bool managed = false, busy = false, reviewing = false, failed = false;
  String query = '';
  String? message;
  String? unavailableReason;
  List<PackageRecord>? records;
  int unavailableSources = 0;

  Future<bool> review(String title, List<Widget> content) async {
    final previousFocus = FocusManager.instance.primaryFocus;
    setState(() => reviewing = true);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialog) => CopyScope(
        preferences: CopyScope.of(context),
        child: AlertDialog(
          title: UiText(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const UiText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const UiText('Confirm selected action'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return false;
    setState(() => reviewing = false);
    if (result != true) {
      if (previousFocus?.context != null && previousFocus!.canRequestFocus) {
        previousFocus.requestFocus();
      } else {
        _resultsFocus.requestFocus();
      }
    }
    return result == true;
  }

  Future<bool> readRecords() async {
    try {
      final result = await widget.invoke(
        managed ? 'apps.managed' : 'apps.list',
        {},
      );
      if (managed && result['available'] == false) {
        final reason = _text(result['reason'], limit: 2048);
        if (result['records'] is! List ||
            (result['records'] as List).isNotEmpty)
          throw const FormatException();
        if (mounted)
          setState(() {
            records = null;
            unavailableReason = reason;
          });
        return false;
      }
      final next = PackageRecord.parse(result, managed: managed);
      final unavailable = managed ? <dynamic>[] : result['unavailable'];
      if (unavailable is! List || unavailable.length > 100)
        throw const FormatException();
      for (final item in unavailable) {
        _text(item, limit: 2048);
      }
      if (mounted)
        setState(() {
          records = next;
          unavailableSources = unavailable.length;
          unavailableReason = null;
        });
      return true;
    } catch (_) {
      if (mounted)
        setState(() {
          records = null;
          unavailableSources = 0;
          unavailableReason = null;
        });
      return false;
    }
  }

  Future<void> load() async {
    if (busy || reviewing) return;
    if (managed &&
        !await review('Discover WinGet packages?', [
          const UiText(
            'WinGet may contact its configured source to match installed packages. No packages will be changed, and new source agreements will not be accepted.',
          ),
        ]))
      return;
    if (!mounted) return;
    final focusBeforeLoad = FocusManager.instance.primaryFocus;
    setState(() {
      busy = true;
      records = null;
      message = null;
      unavailableSources = 0;
      unavailableReason = null;
    });
    final loaded = await readRecords();
    if (mounted)
      setState(() {
        busy = false;
        failed = !loaded;
        message = loaded
            ? 'Application records refreshed.'
            : unavailableReason != null
            ? 'WinGet discovery is unavailable.'
            : 'Application records are unavailable or invalid. No package change was requested.';
      });
    if (mounted &&
        loaded &&
        identical(FocusManager.instance.primaryFocus, focusBeforeLoad)) {
      _resultsFocus.requestFocus();
    }
  }

  Future<void> change(PackageRecord record, {required bool upgrade}) async {
    if (!managed ||
        busy ||
        reviewing ||
        record.packageId == null ||
        !(upgrade ? record.canUpgrade : record.canUninstall))
      return;
    if (!await review(upgrade ? 'Review package upgrade' : 'Review package removal', [
      SelectableText(record.packageId!),
      const SizedBox(height: 12),
      Text(
        '${localize(context, 'Installed version')}: ${record.version ?? localize(context, 'Unavailable')}',
      ),
      const SizedBox(height: 12),
      UiText(
        upgrade
            ? 'WinGet will check whether this exact package can be upgraded. No newer version has been confirmed.'
            : 'WinGet will request removal of this exact package. This workspace does not create a rollback copy.',
      ),
      const SizedBox(height: 12),
      const UiText(
        'WinGet may contact its source and request system consent. The installed version can change after this review. No other package is selected.',
      ),
    ]))
      return;
    if (!mounted) return;
    setState(() {
      busy = true;
      message = null;
    });
    var completed = false;
    try {
      final result = await widget.invoke(
        upgrade ? 'apps.upgrade' : 'apps.uninstall',
        {'packageId': record.packageId, 'confirmed': true},
      );
      if (result['packageId'] != record.packageId ||
          result['completed'] is! bool ||
          result['exitCode'] is! int ||
          result['restartInitiated'] != false ||
          ((result['completed'] == true) != (result['exitCode'] == 0)))
        throw const FormatException();
      completed = result['completed'] == true;
    } catch (_) {
      /* Completion is never inferred from a request or exception. */
    }
    if (!mounted) return;
    final loaded = await readRecords();
    if (mounted)
      setState(() {
        busy = false;
        failed = !completed || !loaded;
        message = completed && loaded
            ? 'Selected package operation completed and records refreshed.'
            : completed
            ? 'The package operation completed, but refreshed records are unavailable.'
            : 'Package completion was not confirmed. Review refreshed records before trying again.';
      });
  }

  @override
  Widget build(BuildContext context) {
    final needle = query.toLowerCase();
    final shown = (records ?? <PackageRecord>[])
        .where(
          (record) => record.searchText(context).toLowerCase().contains(needle),
        )
        .toList();
    return Scaffold(
      appBar: inspectionAppBar(context, 'Apps'),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Focus(
            focusNode: _resultsFocus,
            onKeyEvent: _scrollKey,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(24),
              children: [
                UiText(
                  'Review installed applications',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                const UiText(
                  'General inventory is read-only. Exact WinGet matches provide separately reviewed package actions.',
                ),
                const SizedBox(height: 16),
                LabeledControl(
                  label: localize(context, 'Inventory source'),
                  child: DropdownButtonFormField<bool>(
                    initialValue: managed,
                    isExpanded: true,
                    isDense: false,
                    itemHeight: null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: false,
                        child: const UiText('Installed applications'),
                      ),
                      DropdownMenuItem(
                        value: true,
                        child: const UiText('WinGet matches'),
                      ),
                    ],
                    onChanged: busy || reviewing
                        ? null
                        : (value) => setState(() {
                            managed = value!;
                            records = null;
                            unavailableSources = 0;
                            unavailableReason = null;
                            message = null;
                            failed = false;
                          }),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: busy || reviewing ? null : load,
                    icon: const Icon(Icons.refresh),
                    label: UiText(
                      managed ? 'Discover WinGet packages' : 'Refresh records',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                LabeledSearchBar(
                  label: localize(context, 'Filter application records'),
                  leading: const Icon(Icons.search),
                  onChanged: (value) => setState(() => query = value),
                ),
                const SizedBox(height: 16),
                OperationMotion(
                  state: busy
                      ? 'working'
                      : failed
                      ? 'error'
                      : records != null
                      ? 'complete'
                      : 'idle',
                ),
                if (busy) const LinearProgressIndicator(),
                if (message != null)
                  Semantics(
                    liveRegion: true,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: UiText(message!),
                      ),
                    ),
                  ),
                if (unavailableReason != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: UiText(unavailableReason!),
                    ),
                  ),
                if (records == null && message == null && !busy)
                  const UiText(
                    'Select an inventory source and refresh to begin. No package changes occur during discovery.',
                  ),
                if (unavailableSources > 0)
                  const UiText(
                    'Some inventory sources could not be read. Displayed records are incomplete.',
                  ),
                if (records != null &&
                    records!.any((record) => record.degraded))
                  Text(
                    '${localize(context, 'Records with unavailable display metadata')}: ${records!.where((record) => record.degraded).length}',
                  ),
                if (managed)
                  const UiText(
                    'Only installed WinGet matches are listed. Available update versions have not been checked.',
                  ),
                if (records != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '${localize(context, 'Matching entries')}: ${shown.length} / ${records!.length}',
                    ),
                  ),
                if (records != null && shown.isEmpty)
                  const UiText(
                    'No application records match the current filter.',
                  ),
                for (final record in shown)
                  Card(
                    key: ValueKey(record.id),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SelectableText(
                            record.displayName(context),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${localize(context, 'Installed version')}: ${record.displayVersion(context)}',
                          ),
                          if (record.displayPublisher(context) != null)
                            Text(
                              '${localize(context, 'Publisher')}: ${record.displayPublisher(context)}',
                            ),
                          UiText(
                            record.source == 'winget'
                                ? 'Matched by WinGet'
                                : record.source == 'appx'
                                ? 'Current-user packaged application'
                                : 'Installed application registry',
                          ),
                          if (record.scope != null)
                            UiText(
                              record.scope == 'user'
                                  ? 'Current user'
                                  : 'All users',
                            ),
                          if (record.packageId == null)
                            const UiText(
                              'Read-only record. Use a verified WinGet match for package actions.',
                            ),
                          if (record.canUpgrade || record.canUninstall)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  if (record.canUpgrade)
                                    OutlinedButton.icon(
                                      onPressed: busy || reviewing
                                          ? null
                                          : () => change(record, upgrade: true),
                                      icon: const Icon(Icons.system_update_alt),
                                      label: const UiText('Review upgrade'),
                                    ),
                                  if (record.canUninstall)
                                    OutlinedButton.icon(
                                      onPressed: busy || reviewing
                                          ? null
                                          : () =>
                                                change(record, upgrade: false),
                                      icon: const Icon(Icons.delete_outline),
                                      label: const UiText('Review uninstall'),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
