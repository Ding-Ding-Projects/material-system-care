import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'localization.dart';
import 'motion.dart';

typedef FileUseInvoke =
    Future<Map<String, dynamic>> Function(
      String method,
      Map<String, dynamic> parameters,
    );

class FileUsePage extends StatefulWidget {
  const FileUsePage({super.key, required this.invoke, this.pickFile});
  final FileUseInvoke invoke;
  final Future<String?> Function()? pickFile;
  @override
  State<FileUsePage> createState() => _FileUsePageState();
}

class _FileUsePageState extends State<FileUsePage> {
  final path = TextEditingController();
  bool busy = false;
  String? error;
  String? inspectedPath;
  List<Map<String, dynamic>>? owners;

  @override
  void dispose() {
    path.dispose();
    super.dispose();
  }

  void clearResult() {
    owners = null;
    inspectedPath = null;
    error = null;
  }

  Future<void> choose() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final selected =
          await (widget.pickFile?.call() ??
              const MethodChannel(
                'material_system_care/engine',
              ).invokeMethod<String>('pickFile', <String, dynamic>{}));
      if (!mounted || selected == null) return;
      setState(() {
        path.text = selected;
        clearResult();
      });
    } catch (_) {
      if (mounted)
        setState(() {
          clearResult();
          error =
              'The file picker is unavailable. Enter a full local file path.';
        });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> inspect() async {
    if (busy) return;
    final selected = path.text.trim();
    setState(() {
      clearResult();
      busy = true;
    });
    try {
      final result = await widget.invoke('files.lockOwners', {
        'path': selected,
      });
      if (result['requestedPath'] != selected ||
          result['path'] is! String ||
          (result['path'] as String).isEmpty ||
          result['owners'] is! List ||
          (result['owners'] as List).length > 1024) {
        throw const FormatException();
      }
      final rows = (result['owners'] as List).map((value) {
        final row = Map<String, dynamic>.from(value as Map);
        if (row['processId'] is! int ||
            (row['processId'] as int) <= 0 ||
            row['name'] is! String ||
            row['service'] is! String ||
            row['restartable'] is! bool)
          throw const FormatException();
        return row;
      }).toList();
      if (mounted)
        setState(() {
          owners = rows;
          inspectedPath = result['path'] as String;
        });
    } catch (failure) {
      final code = failure is StateError
          ? failure.message.toString().split(':').first
          : '';
      final reason = switch (code) {
        'INVALID_PARAMETERS' =>
          'Choose an existing file using its full local path.',
        'LOCK_QUERY_BUSY' => 'File use changed during inspection. Try again.',
        'RESULT_TOO_LARGE' =>
          'Too many affected records were reported. No partial result is shown.',
        'PLATFORM_UNSUPPORTED' => 'File-use inspection requires Windows.',
        'LOCK_QUERY_UNAVAILABLE' =>
          'Windows Restart Manager could not inspect this file.',
        _ =>
          'File-use inspection is unavailable. No process or handle was closed.',
      };
      if (mounted) setState(() => error = reason);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        CopyScope.of(context)['reducedMotion'] == true;
    return Scaffold(
      appBar: AppBar(title: const UiText('File use')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              UiText(
                'Inspect a file in use',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              const UiText(
                'Restart Manager reports affected applications and services, not every possible file handle. Results can change after inspection.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: path,
                enabled: !busy,
                maxLength: 1024,
                decoration: InputDecoration(
                  labelText: localize(context, 'Local file path'),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(clearResult),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) inspect();
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : choose,
                    icon: const Icon(Icons.file_open_outlined),
                    label: const UiText('Choose file'),
                  ),
                  FilledButton.icon(
                    onPressed: busy || path.text.trim().isEmpty
                        ? null
                        : inspect,
                    icon: const Icon(Icons.manage_search),
                    label: const UiText('Inspect file use'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OperationMotion(
                state: busy
                    ? 'working'
                    : error != null
                    ? 'error'
                    : owners != null
                    ? 'complete'
                    : 'idle',
              ),
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                Semantics(liveRegion: true, child: UiText(error!)),
              if (owners == null && !busy && error == null)
                const UiText(
                  'Choose a file, then inspect. Nothing is collected automatically.',
                ),
              AnimatedSize(
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                alignment: Alignment.topCenter,
                child: owners == null
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          const UiText('Inspected file'),
                          SelectableText(inspectedPath!),
                          if (owners!.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: UiText(
                                'No affected applications were reported. This does not prove that the file is unlocked.',
                              ),
                            ),
                          ...owners!.map(
                            (row) => Card.outlined(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      row['name'] as String,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text('PID ${row['processId']}'),
                                    if ((row['service'] as String).isNotEmpty)
                                      Text(
                                        '${localize(context, 'Service')}: ${row['service']}',
                                      ),
                                    UiText(
                                      row['restartable'] == true
                                          ? 'Restart Manager marks this record as restartable. No restart is requested.'
                                          : 'Restart Manager does not mark this record as restartable.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const Divider(height: 32),
              const UiText(
                'This inspection does not close processes or handles, unlock files, or change file contents.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
