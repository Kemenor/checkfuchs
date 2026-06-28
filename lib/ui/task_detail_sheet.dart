import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/analytics.dart';
import '../domain/task.dart';
import '../providers.dart';
import 'edit_repeat_sheet.dart';

/// Tap a task → this sheet: rename, delete this occurrence, or delete the whole
/// series (recurring only). Delete is the one sanctioned use of `error` red
/// (DESIGN_SYSTEM §1.3). The full this-vs-series *editing* + turn-into-series
/// come later; this covers rename + delete.
Future<void> showTaskDetailSheet(
    BuildContext context, WidgetRef ref, Task task) {
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
  bool _paused = false;
  HabitStats? _stats;

  @override
  void initState() {
    super.initState();
    final tid = widget.task.templateId;
    if (tid != null) {
      final repo = ref.read(taskRepositoryProvider);
      repo.isTemplatePaused(tid).then((p) {
        if (mounted) setState(() => _paused = p);
      });
      repo.tasksForTemplate(tid).then((tasks) {
        if (mounted) setState(() => _stats = computeStats(tasks));
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _controller.text.trim();
    if (name.isNotEmpty && name != widget.task.name) {
      await ref.read(taskRepositoryProvider).renameTask(widget.task.id!, name);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete({required bool series}) async {
    final repo = ref.read(taskRepositoryProvider);
    if (series && widget.task.templateId != null) {
      await repo.deleteTemplate(widget.task.templateId!);
    } else {
      await repo.deleteTask(widget.task.id!);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recurring = widget.task.templateId != null;
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
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Save'),
              ),
            ),
            if (_stats?.hasData ?? false) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.local_fire_department_rounded,
                      size: 18, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text('${_stats!.currentStreak}-day streak',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 14),
                  Text('${(_stats!.completionRate * 100).round()}% done',
                      style: TextStyle(color: scheme.outline)),
                ],
              ),
            ],
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_repeat),
              title: Text(recurring ? 'Edit repeat' : 'Make it a habit'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showEditRepeatSheet(context, ref, widget.task),
            ),
            if (recurring)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.pause_circle_outline),
                title: const Text('Paused'),
                subtitle: const Text('Stop generating new instances'),
                value: _paused,
                onChanged: (v) async {
                  await ref
                      .read(taskRepositoryProvider)
                      .pauseTemplate(widget.task.templateId!, v);
                  if (mounted) setState(() => _paused = v);
                },
              ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => _delete(series: false),
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              icon: const Icon(Icons.delete_outline),
              label: Text(recurring ? 'Delete this task' : 'Delete task'),
            ),
            if (recurring)
              TextButton.icon(
                onPressed: () => _delete(series: true),
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Delete the whole series'),
              ),
          ],
        ),
      ),
    );
  }
}
