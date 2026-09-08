import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/recurrence.dart';
import '../domain/task.dart';
import '../domain/window_rule.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'recurrence_editor.dart';
import 'window_choice.dart';
import 'window_editor.dart';

/// Edit a task's repeat rule (design-concept §3.6, §5.2):
/// - one-off + a rule  → **turn into a series**
/// - series + new rule → **edit the series** (prospective)
/// - series + Off      → **stop repeating** (existing tasks become one-offs)
Future<void> showEditRepeatSheet(
  BuildContext context,
  WidgetRef ref,
  Task task,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EditRepeatSheet(task: task),
  );
}

class _EditRepeatSheet extends ConsumerStatefulWidget {
  const _EditRepeatSheet({required this.task});
  final Task task;

  @override
  ConsumerState<_EditRepeatSheet> createState() => _EditRepeatSheetState();
}

class _EditRepeatSheetState extends ConsumerState<_EditRepeatSheet> {
  bool _loading = true;
  Recurrence? _initial;
  Recurrence? _recurrence;
  WindowRule _windowRule = const UntilNextOccurrence();

  /// The chip form of [_windowRule]; null when the stored rule has none (then
  /// the editor is hidden and the rule passes through untouched).
  WindowSelection? _window = WindowSelection.anytime;

  bool get _wasSeries => widget.task.templateId != null;

  @override
  void initState() {
    super.initState();
    if (_wasSeries) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    final cfg = await ref
        .read(taskRepositoryProvider)
        .templateConfig(widget.task.templateId!);
    if (!mounted) return;
    setState(() {
      _initial = cfg?.recurrence;
      _recurrence = cfg?.recurrence;
      _windowRule = cfg?.windowRule ?? const UntilNextOccurrence();
      _window = WindowSelection.fromRule(_windowRule);
      _loading = false;
    });
  }

  Future<void> _save() async {
    final repo = ref.read(taskRepositoryProvider);
    final now = ref.read(clockProvider).now();
    final r = _recurrence;
    final rule = _window?.toRule() ?? _windowRule;

    if (_wasSeries) {
      if (r != null) {
        await repo.updateTemplateConfig(widget.task.templateId!, r, rule, now);
      } else {
        await repo.stopRepeating(widget.task.templateId!);
      }
    } else if (r != null) {
      await repo.turnIntoSeries(widget.task, r, rule, now);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final now = ref.read(clockProvider).now();
    final anchor = DateTime(now.year, now.month, now.day);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, viewInsets + 16),
      child: SafeArea(
        top: false,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _wasSeries ? l10n.editRepeat : l10n.makeItAHabit,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    RecurrenceEditor(
                      anchor: anchor,
                      initial: _initial,
                      onChanged: (r) => setState(() => _recurrence = r),
                    ),
                    // The series' active window (§3.3) — shown whenever the
                    // result is a series, i.e. not for "stop repeating".
                    if (_recurrence != null && _window != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        l10n.activeWindowSection.toUpperCase(),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .6,
                            ),
                      ),
                      const SizedBox(height: 8),
                      WindowEditor(
                        value: _window!,
                        onChanged: (w) => setState(() => _window = w),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _save,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(l10n.save),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
