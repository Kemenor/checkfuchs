import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/recurrence.dart';
import '../domain/task.dart';
import '../domain/template.dart';
import '../domain/window_rule.dart';
import '../providers.dart';
import 'recurrence_editor.dart';

/// Create a task or habit (Phase 3): name + recurrence (Off = one-off) + an
/// active-window picker. A recurrence makes a Template; "Off" makes a one-off
/// Task. Reconciles so the first instance appears immediately.
Future<void> showCreateTaskSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _CreateTaskSheet(),
  );
}

enum _WindowChoice {
  anytime('Anytime'),
  morning('Morning'),
  afternoon('Afternoon'),
  evening('Evening');

  const _WindowChoice(this.label);
  final String label;

  WindowRule toRule() => switch (this) {
        _WindowChoice.anytime => const UntilNextOccurrence(),
        _WindowChoice.morning => Slice.morning,
        _WindowChoice.afternoon => Slice.afternoon,
        _WindowChoice.evening => Slice.evening,
      };

  /// (start, end) for a one-off on [today]. "Anytime" = unbounded (never misses).
  (DateTime?, DateTime?) oneOffWindow(DateTime today) => switch (this) {
        _WindowChoice.anytime => (null, null),
        _WindowChoice.morning => (today, today.add(const Duration(hours: 12))),
        _WindowChoice.afternoon => (
            today.add(const Duration(hours: 12)),
            today.add(const Duration(hours: 18))
          ),
        _WindowChoice.evening => (
            today.add(const Duration(hours: 18)),
            today.add(const Duration(hours: 24))
          ),
      };
}

class _CreateTaskSheet extends ConsumerStatefulWidget {
  const _CreateTaskSheet();

  @override
  ConsumerState<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends ConsumerState<_CreateTaskSheet> {
  final _controller = TextEditingController();
  Recurrence? _recurrence;
  _WindowChoice _window = _WindowChoice.anytime;

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

    if (_recurrence != null) {
      await repo.createTemplate(Template(
        name: name,
        recurrence: _recurrence!,
        windowRule: _window.toRule(),
        createdAt: now,
      ));
    } else {
      final (start, end) = _window.oneOffWindow(today);
      await repo.createTask(
          Task(name: name, start: start, end: end, createdAt: now));
    }
    await repo.reconcileAll(now);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final now = ref.read(clockProvider).now();
    final anchor = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, viewInsets + 16),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New task', style: Theme.of(context).textTheme.titleLarge),
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
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              _SectionLabel('Active window'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final w in _WindowChoice.values)
                    ChoiceChip(
                      label: Text(w.label),
                      selected: _window == w,
                      onSelected: (_) => setState(() => _window = w),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionLabel('Repeat'),
              const SizedBox(height: 10),
              RecurrenceEditor(
                anchor: anchor,
                onChanged: (r) => setState(() => _recurrence = r),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _controller.text.trim().isEmpty ? null : _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.outline,
            fontWeight: FontWeight.w700,
            letterSpacing: .6,
          ),
    );
  }
}
