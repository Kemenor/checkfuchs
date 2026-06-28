import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuchsbau/fuchsbau.dart';

import '../domain/task.dart';
import '../providers.dart';
import 'task_detail_sheet.dart';

/// A single Task row on the Today surface (DESIGN_SYSTEM §3.1): the marker on
/// the left (tap the ring to complete), the name, and swipe-to-Skip.
class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final status = FuchsbauStatusColors.of(context);
    final now = ref.read(clockProvider).now();
    final phase = phaseOf(task, now);

    final (IconData icon, Color color, bool actionable) = switch (phase) {
      TaskPhase.active => (Icons.radio_button_unchecked, scheme.primary, true),
      TaskPhase.pending => (Icons.schedule, scheme.outline, false),
      TaskPhase.expired => (Icons.radio_button_unchecked, status.taupe, false),
    };

    return Dismissible(
      key: ValueKey('task-${task.id}'),
      direction: DismissDirection.endToStart,
      // The reactive stream removes the row once it's no longer open, so we
      // don't let Dismissible animate it away itself (avoids a double-remove).
      confirmDismiss: (_) async {
        await ref
            .read(taskRepositoryProvider)
            .skipTask(task, ref.read(clockProvider).now());
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: status.neutral.withValues(alpha: .18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.remove_circle_outline, color: status.neutral),
            const SizedBox(width: 8),
            Text('Skip', style: TextStyle(color: status.neutral, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      child: ListTile(
        minVerticalPadding: 14,
        onTap: () => showTaskDetailSheet(context, ref, task),
        leading: IconButton(
          iconSize: 26,
          icon: Icon(icon, color: color),
          onPressed: actionable
              ? () => ref
                  .read(taskRepositoryProvider)
                  .completeTask(task, ref.read(clockProvider).now())
              : null,
        ),
        title: Text(
          task.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: phase == TaskPhase.pending
            ? Text('soon',
                style: TextStyle(color: scheme.outline, fontSize: 12, fontWeight: FontWeight.w600))
            : null,
      ),
    );
  }
}
