import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/analytics.dart';
import '../domain/task.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'edit_repeat_sheet.dart';

/// Tap a task → this sheet: rename, delete this occurrence, or delete the whole
/// series (recurring only). Delete is the one sanctioned use of `error` red
/// (DESIGN_SYSTEM §1.3). The full this-vs-series *editing* + turn-into-series
/// come later; this covers rename + delete.
Future<void> showTaskDetailSheet(
  BuildContext context,
  WidgetRef ref,
  Task task,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TaskDetailSheet(task: task),
  );
}

class _TaskDetailSheet extends ConsumerStatefulWidget {
  const _TaskDetailSheet({required this.task});
  final Task task;

  @override
  ConsumerState<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<_TaskDetailSheet> {
  late final _controller = TextEditingController(text: widget.task.name);

  /// The live task — re-read after nested sheets mutate it (turn-into-series /
  /// stop-repeating change `templateId`, which drives most of this sheet).
  late Task _task = widget.task;
  bool _paused = false;
  HabitStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadSeriesInfo();
  }

  void _loadSeriesInfo() {
    final tid = _task.templateId;
    if (tid == null) {
      setState(() {
        _paused = false;
        _stats = null;
      });
      return;
    }
    final repo = ref.read(taskRepositoryProvider);
    repo.isTemplatePaused(tid).then((p) {
      if (mounted) setState(() => _paused = p);
    });
    repo.tasksForTemplate(tid).then((tasks) {
      if (mounted) setState(() => _stats = computeStats(tasks));
    });
  }

  Future<void> _editRepeat() async {
    await showEditRepeatSheet(context, ref, _task);
    if (!mounted || _task.id == null) return;
    // The nested sheet may have converted/stopped the series (the original
    // task row can be replaced by the first generated instance) — re-read.
    final fresh = await ref.read(taskRepositoryProvider).taskById(_task.id!);
    if (!mounted) return;
    if (fresh == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _task = fresh);
    _loadSeriesInfo();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _controller.text.trim();
    if (name.isNotEmpty && name != _task.name) {
      await ref.read(taskRepositoryProvider).renameTask(_task.id!, name);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete({required bool series}) async {
    final repo = ref.read(taskRepositoryProvider);
    if (series && _task.templateId != null) {
      await repo.deleteTemplate(_task.templateId!);
    } else {
      await repo.deleteTask(_task.id!);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final recurring = _task.templateId != null;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, viewInsets + 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.sentences,
              style: Theme.of(context).textTheme.titleLarge,
              decoration: const InputDecoration(border: InputBorder.none),
              onSubmitted: (_) => _saveName(),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saveName,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(l10n.save),
              ),
            ),
            if (_stats?.hasData ?? false) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.dayStreak(_stats!.currentStreak),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    l10n.percentDone((_stats!.completionRate * 100).round()),
                    style: TextStyle(color: scheme.outline),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_repeat),
              title: Text(recurring ? l10n.editRepeat : l10n.makeItAHabit),
              trailing: const Icon(Icons.chevron_right),
              onTap: _editRepeat,
            ),
            if (recurring)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.pause_circle_outline),
                title: Text(l10n.paused),
                subtitle: Text(l10n.pausedSubtitle),
                value: _paused,
                onChanged: (v) async {
                  await ref
                      .read(taskRepositoryProvider)
                      .pauseTemplate(
                        _task.templateId!,
                        v,
                        ref.read(clockProvider).now(),
                      );
                  if (mounted) setState(() => _paused = v);
                },
              ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => _delete(series: false),
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              icon: const Icon(Icons.delete_outline),
              label: Text(recurring ? l10n.deleteThisTask : l10n.deleteTask),
            ),
            if (recurring)
              TextButton.icon(
                onPressed: () => _delete(series: true),
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(l10n.deleteWholeSeries),
              ),
          ],
        ),
      ),
    );
  }
}
