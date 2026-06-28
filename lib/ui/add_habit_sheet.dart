import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/recurrence.dart';
import '../domain/template.dart';
import '../providers.dart';

/// Minimal "add a daily habit" sheet for the Phase 2 carrier MVP — just a name.
/// It creates a daily Template with a full-day window (active until midnight),
/// then reconciles so the first instance appears immediately. The full
/// recurrence/window editor is Phase 3.
Future<void> showAddHabitSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _AddHabitSheet(),
  );
}

class _AddHabitSheet extends ConsumerStatefulWidget {
  const _AddHabitSheet();

  @override
  ConsumerState<_AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends ConsumerState<_AddHabitSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(taskRepositoryProvider);
    final now = ref.read(clockProvider).now();
    final today = DateTime(now.year, now.month, now.day);
    await repo.createTemplate(Template(
      name: name,
      recurrence: Recurrence.daily(today),
      createdAt: now,
    ));
    await repo.reconcileAll(now);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, viewInsets + 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New daily habit',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Brush teeth',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
