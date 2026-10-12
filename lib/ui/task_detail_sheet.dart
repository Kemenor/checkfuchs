import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuchsbau/fuchsbau.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/db/database.dart';
import '../data/repositories/task_repository.dart';
import '../domain/analytics.dart';
import '../domain/goal.dart';
import '../domain/notification.dart';
import '../domain/recurrence.dart';
import '../domain/task.dart';
import '../domain/window_rule.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'edit_repeat_sheet.dart';
import 'goal_editor.dart';
import 'goal_ring.dart';
import 'recurrence_summary_l10n.dart';
import 'reminder_editor.dart';
import 'task_history_screen.dart';
import 'when_label.dart';
import 'window_choice.dart';
import 'window_editor.dart';

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

/// One window edge on the detail sheet: absolute day (+ clock time when one
/// is set — a midnight end reads as its evening's day, never "00:00").
class _WindowDateTile extends StatelessWidget {
  const _WindowDateTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.isEnd,
    required this.onTap,
    required this.onClear,
  });

  final IconData icon;
  final String label;
  final DateTime? value;
  final String placeholder;
  final bool isEnd;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final v = value;
    String text;
    if (v == null) {
      text = placeholder;
    } else {
      final wholeDay = v.hour == 0 && v.minute == 0;
      final day = isEnd && wholeDay
          ? v.subtract(const Duration(minutes: 1))
          : v;
      text = DateFormat.yMMMEd(locale).format(day);
      if (!wholeDay) text = '$text · ${DateFormat.Hm(locale).format(v)}';
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(
        text,
        style: v == null ? TextStyle(color: scheme.outline) : null,
      ),
      trailing: v == null
          ? const Icon(Symbols.chevron_right_rounded)
          : IconButton(
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              icon: const Icon(Symbols.close_rounded),
              onPressed: onClear,
            ),
      onTap: onTap,
    );
  }
}

class _TaskDetailSheet extends ConsumerStatefulWidget {
  const _TaskDetailSheet({required this.task});
  final Task task;

  @override
  ConsumerState<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<_TaskDetailSheet> {
  late final _controller = TextEditingController(text: widget.task.name);
  late final _noteController = TextEditingController(
    text: widget.task.note ?? '',
  );
  final _nameFocus = FocusNode();
  final _noteFocus = FocusNode();

  /// Captured once: `ref` is gone by the time [dispose] runs, and the last
  /// edit still has to reach the database.
  late final TaskRepository _repo = ref.read(taskRepositoryProvider);

  /// The live task — re-read after nested sheets mutate it (turn-into-series /
  /// stop-repeating change `templateId`, which drives most of this sheet).
  late Task _task = widget.task;
  late List<TaskNotification> _notifications = _task.notifications;
  bool _paused = false;
  HabitStats? _stats;

  /// The series' recurrence + window rule (null until loaded / for one-offs).
  Recurrence? _templateRecurrence;
  WindowRule? _templateRule;
  Goal _templateGoal = Goal.single;
  List<LensRow> _lenses = const [];
  Set<int> _lensIds = const {};

  Future<void> _setReminders(List<TaskNotification> n) async {
    final hadNone = _notifications.isEmpty;
    setState(() => _notifications = n);
    final repo = ref.read(taskRepositoryProvider);
    if (hadNone && n.isNotEmpty) await ensureNotificationPermission(ref);
    // A series edit updates the defaults AND the open instances; a one-off
    // edit touches just this task.
    if (_task.templateId != null) {
      await repo.setTemplateNotifications(_task.templateId!, n);
    } else if (_task.id != null) {
      await repo.setTaskNotifications(_task.id!, n);
    }
    _task = _task.copyWith(notifications: n);
  }

  @override
  void initState() {
    super.initState();
    // Everything on this sheet saves itself; the text fields commit when they
    // lose focus and again when the sheet goes away, so a rename followed by
    // a swipe-down is never lost.
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) _commitText();
    });
    _noteFocus.addListener(() {
      if (!_noteFocus.hasFocus) _commitText();
    });
    _loadSeriesInfo();
    _loadLensInfo();
  }

  Future<void> _loadLensInfo() async {
    final lenses = await ref
        .read(viewRepositoryProvider)
        .watchAllLenses()
        .first;
    final lensIds = _task.id == null
        ? const <int>{}
        : await ref.read(taskRepositoryProvider).taskLensIds(_task.id!);
    if (!mounted) return;
    setState(() {
      _lenses = lenses;
      _lensIds = lensIds;
    });
  }

  /// Choose the lenses this task (or its whole series — membership is a
  /// series property, not a per-occurrence one) lives in. Multi-select; the
  /// last lens can't be unticked because a task in no lens is invisible.
  Future<void> _pickLenses() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showDialog<Set<int>>(
      context: context,
      builder: (ctx) => _LensPickerDialog(
        title: l10n.lensSection,
        lenses: _lenses,
        initial: _lensIds,
      ),
    );
    if (picked == null || setEquals(picked, _lensIds)) return;
    final repo = ref.read(taskRepositoryProvider);
    if (_task.templateId != null) {
      await repo.setTemplateLenses(_task.templateId!, picked);
    } else if (_task.id != null) {
      await repo.setTaskLenses(_task.id!, picked);
    }
    if (mounted) setState(() => _lensIds = picked);
  }

  /// Edit one window edge of an open one-off. The date picker chooses the
  /// day; an existing wall-clock time survives the move (a 17:00 deadline
  /// pushed to the 29th is still 17:00), a bare date keeps whole-day
  /// semantics (due = midnight after, start = midnight of).
  Future<void> _editWindowDate({required bool isEnd}) async {
    final now = ref.read(clockProvider).now();
    final today = DateTime(now.year, now.month, now.day);
    final old = isEnd ? _task.end : _task.start;
    final oldDay = old == null ? null : DateTime(old.year, old.month, old.day);
    var first = isEnd ? (_task.start ?? today) : today;
    first = DateTime(first.year, first.month, first.day);
    if (oldDay != null && oldDay.isBefore(first)) first = oldDay;
    final initial = oldDay ?? today;
    final picked = await showDatePicker(
      context: context,
      // A future start with no due yet: the picker asserts
      // initialDate >= firstDate, so clamp.
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(today.year + 5, 12, 31),
    );
    if (picked == null) return;
    await _writeWindow(_apply(picked, old, isEnd: isEnd), isEnd: isEnd);
  }

  static DateTime _apply(DateTime day, DateTime? old, {required bool isEnd}) {
    final wholeDay = old == null || (old.hour == 0 && old.minute == 0);
    if (isEnd && wholeDay) return DateTime(day.year, day.month, day.day + 1);
    if (wholeDay) return DateTime(day.year, day.month, day.day);
    return DateTime(day.year, day.month, day.day, old.hour, old.minute);
  }

  Future<void> _writeWindow(DateTime? value, {required bool isEnd}) async {
    final start = isEnd ? _task.start : value;
    final end = isEnd ? value : _task.end;
    await ref.read(taskRepositoryProvider).setTaskWindow(_task.id!, start, end);
    if (mounted) {
      setState(() => _task = _task.copyWith(start: start, end: end));
    }
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
    repo.templateConfig(tid).then((cfg) {
      if (mounted) {
        setState(() {
          _templateRecurrence = cfg?.recurrence;
          _templateRule = cfg?.windowRule;
          _templateGoal = cfg?.goal ?? Goal.single;
        });
      }
    });
  }

  /// The series' active window (§3.3): chips + custom bands, applied
  /// prospectively like any series edit — the running instance keeps its
  /// window, the next one gets the new rule.
  Future<void> _editSeriesWindow() async {
    final rule = _templateRule;
    final recurrence = _templateRecurrence;
    if (rule == null || recurrence == null) return;
    final initial = WindowSelection.fromRule(rule);
    if (initial == null) return;
    final picked = await showModalBottomSheet<WindowSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _WindowSheet(initial: initial),
    );
    if (picked == null || !mounted) return;
    final newRule = picked.toRule();
    if (newRule == rule) return;
    await ref
        .read(taskRepositoryProvider)
        .updateTemplateConfig(
          _task.templateId!,
          recurrence,
          newRule,
          ref.read(clockProvider).now(),
        );
    if (mounted) setState(() => _templateRule = newRule);
  }

  /// The series' goal (§3.7) — applied to the running instance at once.
  Future<void> _editGoal() async {
    final recurrence = _templateRecurrence;
    final rule = _templateRule;
    if (recurrence == null || rule == null) return;
    final picked = await showModalBottomSheet<Goal>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GoalSheet(
        initial: _templateGoal,
        unit: goalUnit(AppLocalizations.of(context), recurrence),
        spanDays: windowSpanDays(recurrence, rule),
      ),
    );
    if (picked == null || picked == _templateGoal || !mounted) return;
    await ref
        .read(taskRepositoryProvider)
        .setTemplateGoal(
          _task.templateId!,
          picked,
          ref.read(clockProvider).now(),
        );
    await _reload();
  }

  /// A forgotten check-in (§3.7): pick a day inside the window (never past
  /// now), then a time. Rejected picks — a day that already has one under
  /// "once a day", or the cap — say why instead of failing silently.
  Future<void> _addForgottenCheckIn() async {
    final l10n = AppLocalizations.of(context);
    final now = ref.read(clockProvider).now();
    final start = _task.start ?? _task.createdAt;
    final end = _task.end == null || _task.end!.isAfter(now) ? now : _task.end!;
    final first = DateTime(start.year, start.month, start.day);
    // A window ending at midnight doesn't include that day.
    final lastInstant = end.subtract(const Duration(microseconds: 1));
    final last = DateTime(lastInstant.year, lastInstant.month, lastInstant.day);
    final day = await showDatePicker(
      context: context,
      initialDate: last,
      firstDate: first,
      lastDate: last.isBefore(first) ? first : last,
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        day == DateTime(now.year, now.month, now.day) ? now : end,
      ),
    );
    if (time == null || !mounted) return;
    var at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    // Clamp into the window: a picked time before it opens / after it closes
    // on the edge days lands on the edge.
    if (at.isBefore(start)) at = start;
    if (at.isAfter(end)) at = end;
    if (!canAddCheckIn(_task, at, now)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.checkInNotAllowed)));
      return;
    }
    await ref.read(taskRepositoryProvider).addCheckIn(_task, at, now);
    await _reload();
  }

  Future<void> _removeCheckIn(DateTime at) async {
    await ref
        .read(taskRepositoryProvider)
        .removeCheckIn(_task, at, ref.read(clockProvider).now());
    await _reload();
  }

  Future<void> _editRepeat() async {
    await showEditRepeatSheet(context, ref, _task);
    await _reload();
  }

  /// Re-read the task after a nested sheet or a conversion (the original
  /// row can be replaced by the first generated instance, and `templateId`
  /// drives most of this sheet).
  Future<void> _reload() async {
    if (!mounted || _task.id == null) return;
    final fresh = await ref.read(taskRepositoryProvider).taskById(_task.id!);
    if (!mounted) return;
    if (fresh == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _task = fresh;
      _notifications = fresh.notifications;
    });
    _loadSeriesInfo();
  }

  /// The Habit/To-do toggle, live like every other row here. To-do → habit:
  /// a daily series from today (the window keeps the task's own hours; the
  /// Repeat row is right below to refine). Habit → to-do: stop repeating —
  /// confirmed, since the streak and history end there.
  Future<void> _setKind(bool habit) async {
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(taskRepositoryProvider);
    final now = ref.read(clockProvider).now();
    final tid = _task.templateId;
    if (habit && tid == null) {
      await repo.turnIntoSeries(
        _task,
        Recurrence.daily(DateTime(now.year, now.month, now.day)),
        WindowSelection.fromEdges(_task.start, _task.end, _task.bands).toRule(),
        now,
      );
      await _reload();
    } else if (!habit && tid != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.toTodoTitle),
          content: Text(l10n.toTodoBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.kindTodo),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await repo.stopRepeating(tid);
      await _reload();
    }
  }

  @override
  void dispose() {
    _commitText();
    _nameFocus.dispose();
    _noteFocus.dispose();
    _controller.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Commit the name and the note. A series renames as a whole — it is one
  /// habit across its history — and a series' note is the template default
  /// plus its open instances. Safe to call repeatedly: unchanged text writes
  /// nothing.
  void _commitText() {
    final id = _task.id;
    if (id == null) return;
    final name = _controller.text.trim();
    final noteText = _noteController.text.trim();
    final note = noteText.isEmpty ? null : noteText;
    final tid = _task.templateId;
    if (name.isNotEmpty && name != _task.name) {
      if (tid != null) {
        _repo.renameTemplate(tid, name);
      } else {
        _repo.renameTask(id, name);
      }
      _task = _task.copyWith(name: name);
    }
    if (note != _task.note) {
      if (tid != null) {
        _repo.setTemplateNote(tid, note);
      } else {
        _repo.setTaskNote(id, note);
      }
      _task = _task.copyWith(note: note);
    }
  }

  /// The status actions — the reason most people open this sheet. Each one
  /// writes and re-reads in place, so the sheet shows the new state instead
  /// of closing under the user.
  Future<void> _act(
    Future<void> Function(TaskRepository repo, DateTime now) run,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await run(ref.read(taskRepositoryProvider), ref.read(clockProvider).now());
    await _reload();
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Same shape as the create sheet: kind → name/note → lenses →
              // (repeat + window | starts/due) → reminders → save. The sheet
              // fills the screen, so it carries an explicit close — swiping
              // the handle is not discoverable. Closing saves (dispose
              // commits the text fields), like every other way out.
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: true,
                          icon: const Icon(Symbols.event_repeat_rounded),
                          label: Text(l10n.kindHabit),
                        ),
                        ButtonSegment(
                          value: false,
                          icon: const Icon(Symbols.check_circle_rounded),
                          label: Text(l10n.kindTodo),
                        ),
                      ],
                      selected: {recurring},
                      onSelectionChanged: (s) => _setKind(s.first),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: const Icon(Symbols.close_rounded),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                focusNode: _nameFocus,
                textCapitalization: TextCapitalization.sentences,
                style: Theme.of(context).textTheme.titleLarge,
                decoration: const InputDecoration(border: InputBorder.none),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _nameFocus.unfocus(),
              ),
              TextField(
                controller: _noteController,
                focusNode: _noteFocus,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                style: TextStyle(color: scheme.outline),
                decoration: InputDecoration(
                  hintText: l10n.noteHint,
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              _StatusBlock(
                task: _task,
                now: ref.read(clockProvider).now(),
                onDone: () => _act((r, now) => r.checkInTask(_task, now)),
                onSkip: () => _act((r, now) => r.skipTask(_task, now)),
                onCorrectMiss: () => _act((r, _) => r.correctMissedTask(_task)),
                onReopen: () => _act((r, now) => r.reopenTask(_task, now)),
              ),
              if (_stats?.hasData ?? false) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(
                      Symbols.local_fire_department_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      localizedStreak(
                        l10n,
                        _stats!.currentStreak,
                        _templateRecurrence,
                      ),
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
              // A counter's check-ins this cycle (§3.7): each removable, and
              // a forgotten one can be added with its time.
              if (_task.isCounter) ...[
                const SizedBox(height: 12),
                _CheckInList(
                  task: _task,
                  now: ref.read(clockProvider).now(),
                  onRemove: _removeCheckIn,
                  onAdd: _addForgottenCheckIn,
                ),
              ],
              if (recurring)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Symbols.history_rounded),
                  title: Text(l10n.historyTitle),
                  trailing: const Icon(Symbols.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TaskHistoryScreen(
                        templateId: _task.templateId!,
                        name: _task.name,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              if (_lenses.length > 1)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Symbols.filter_alt_rounded),
                  title: Text(l10n.lensSection),
                  subtitle: switch (_lenses.where(
                    (l) => _lensIds.contains(l.id),
                  )) {
                    Iterable(isEmpty: true) => null,
                    final match => Text(match.map((l) => l.name).join(', ')),
                  },
                  trailing: const Icon(Symbols.chevron_right_rounded),
                  onTap: _pickLenses,
                ),
              if (recurring) ...[
                // Repeat, then the active window — the create sheet's order.
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Symbols.event_repeat_rounded),
                  title: Text(l10n.repeatSection),
                  subtitle: _templateRecurrence == null
                      ? null
                      : Text(
                          localizedRecurrenceSummary(
                            context,
                            _templateRecurrence,
                          ),
                        ),
                  trailing: const Icon(Symbols.chevron_right_rounded),
                  onTap: _editRepeat,
                ),
                // Times (§3.7) — between Repeat and the window, as on create.
                if (_templateRecurrence != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Symbols.tag_rounded),
                    title: Text(l10n.timesSection),
                    subtitle: Text(
                      goalRowSummary(
                        l10n,
                        _templateGoal,
                        goalUnit(l10n, _templateRecurrence!),
                      ),
                    ),
                    trailing: const Icon(Symbols.chevron_right_rounded),
                    onTap: _editGoal,
                  ),
                if (_templateRule != null)
                  switch (WindowSelection.fromRule(_templateRule!)) {
                    null => const SizedBox.shrink(),
                    final sel => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Symbols.schedule_rounded),
                      title: Text(l10n.activeWindowSection),
                      subtitle: Text(
                        sel.isAnytime
                            ? l10n.windowAnytime
                            : [
                                if (sel.days != null)
                                  l10n.windowDays(sel.days!),
                                if (!sel.allDay) sel.describe(context),
                              ].join(' · '),
                      ),
                      trailing: const Icon(Symbols.chevron_right_rounded),
                      onTap: _editSeriesWindow,
                    ),
                  },
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Symbols.pause_circle_outline_rounded),
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
              ],
              // A to-do's window is its dates — editable while it's open.
              if (!recurring && _task.isOpen) ...[
                _WindowDateTile(
                  icon: Symbols.today_rounded,
                  label: l10n.starts,
                  value: _task.start,
                  placeholder: l10n.startsNow,
                  isEnd: false,
                  onTap: () => _editWindowDate(isEnd: false),
                  onClear: () => _writeWindow(null, isEnd: false),
                ),
                _WindowDateTile(
                  icon: Symbols.flag_rounded,
                  label: l10n.dueLabel,
                  value: _task.end,
                  placeholder: l10n.noDueDate,
                  isEnd: true,
                  onTap: () => _editWindowDate(isEnd: true),
                  onClear: () => _writeWindow(null, isEnd: true),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Symbols.notifications_none_rounded,
                    size: 20,
                    color: scheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.remindersSection,
                    style: TextStyle(
                      color: scheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ReminderEditor(
                value: _notifications,
                hasDay:
                    _task.occurrence != null ||
                    _task.end != null ||
                    _task.start != null,
                // A preset can only fire if the edge it hangs on exists.
                hasStart: _task.start != null,
                hasEnd: _task.end != null,
                onChanged: _setReminders,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _delete(series: false),
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                icon: const Icon(Symbols.delete_outline_rounded),
                label: Text(recurring ? l10n.deleteThisTask : l10n.deleteTask),
              ),
              if (recurring)
                TextButton.icon(
                  onPressed: () => _delete(series: true),
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  icon: const Icon(Symbols.delete_forever_rounded),
                  label: Text(l10n.deleteWholeSeries),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Checkbox list over all lenses; OK returns the selection. The last ticked
/// lens is locked on — a task must live somewhere.
class _LensPickerDialog extends StatefulWidget {
  const _LensPickerDialog({
    required this.title,
    required this.lenses,
    required this.initial,
  });

  final String title;
  final List<LensRow> lenses;
  final Set<int> initial;

  @override
  State<_LensPickerDialog> createState() => _LensPickerDialogState();
}

class _LensPickerDialogState extends State<_LensPickerDialog> {
  late Set<int> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.only(top: 12),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final lens in widget.lenses)
              CheckboxListTile(
                value: _selected.contains(lens.id),
                title: Text(lens.name),
                onChanged: (on) => setState(() {
                  if (on == true) {
                    _selected = {..._selected, lens.id};
                  } else if (_selected.length > 1) {
                    _selected = {..._selected}..remove(lens.id);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text(MaterialLocalizations.of(context).okButtonLabel),
        ),
      ],
    );
  }
}

/// The active-window picker as a sheet: chips + custom bands, Save returns
/// the selection.
class _WindowSheet extends StatefulWidget {
  const _WindowSheet({required this.initial});
  final WindowSelection initial;

  @override
  State<_WindowSheet> createState() => _WindowSheetState();
}

class _WindowSheetState extends State<_WindowSheet> {
  late WindowSelection _sel = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, viewInsets + 16),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.activeWindowSection,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              WindowEditor(
                value: _sel,
                recurring: true,
                onChanged: (w) => setState(() => _sel = w),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_sel),
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

/// What state this task is in *right now*, and the one or two actions that
/// change it. The sheet's first answer: people open a task to check it off
/// or to see whether they already did.
class _StatusBlock extends StatelessWidget {
  const _StatusBlock({
    required this.task,
    required this.now,
    required this.onDone,
    required this.onSkip,
    required this.onCorrectMiss,
    required this.onReopen,
  });

  final Task task;
  final DateTime now;
  final VoidCallback onDone;
  final VoidCallback onSkip;
  final VoidCallback onCorrectMiss;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final status = FuchsbauStatusColors.of(context);
    final locale = Localizations.localeOf(context).toString();
    final phase = phaseOf(task, now);

    String edge(DateTime t, {required bool isEnd}) =>
        whenLabel(l10n, locale, now, t, isEnd: isEnd);

    var (IconData icon, Color colour, String line) = switch (task.status) {
      TaskStatus.done => (
        Symbols.check_circle_rounded,
        scheme.tertiary,
        task.resolvedAt == null
            ? l10n.stateDone
            : l10n.stateDoneAt(edge(task.resolvedAt!, isEnd: false)),
      ),
      TaskStatus.skipped => (
        Symbols.remove_circle_outline_rounded,
        status.neutral,
        l10n.stateSkipped,
      ),
      TaskStatus.missed => (
        Symbols.radio_button_unchecked_rounded,
        status.taupe,
        l10n.stateMissed,
      ),
      TaskStatus.open => switch (phase) {
        TaskPhase.active => (
          Symbols.radio_button_unchecked_rounded,
          scheme.primary,
          switch (task.end) {
            null => l10n.stateOpenNoDeadline,
            // A window ending at midnight closes *tonight*; "until Today"
            // is not a sentence (DESIGN_SYSTEM §3.6).
            final e
                when e.hour == 0 &&
                    e.minute == 0 &&
                    e.difference(now).inHours < 24 =>
              l10n.stateOpenUntilMidnight,
            final e => l10n.stateOpenUntil(edge(e, isEnd: true)),
          },
        ),
        TaskPhase.pending => (
          Symbols.schedule_rounded,
          scheme.outline,
          task.start == null
              ? l10n.stateWaiting
              : l10n.stateOpensAt(edge(task.start!, isEnd: false)),
        ),
        TaskPhase.expired => (
          Symbols.radio_button_unchecked_rounded,
          status.taupe,
          l10n.stateClosed,
        ),
      },
    };

    // A counter (§3.7) leads with its progress — "1 of 2–3 · Open until
    // Sunday" — and turns emerald once met, though it stays open.
    final counter = task.isCounter;
    if (counter) {
      line = '${l10n.counterProgress(task.count, goalSpan(task.goal))} · $line';
      if (task.isOpen && task.isMet) colour = scheme.tertiary;
    }
    final Widget marker = counter && (task.isOpen || task.isMissed)
        ? GoalRing(count: task.count, goal: task.goal, color: colour, size: 20)
        : Icon(icon, size: 20, color: colour);
    // A counter gives check-ins back one by one from its list; the Reopen
    // button is for a Skip.
    final showReopen =
        canReopen(task) && (!counter || task.status == TaskStatus.skipped);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            marker,
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                line,
                style: TextStyle(color: colour, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (canCheckIn(task, now))
              Expanded(
                child: FilledButton.icon(
                  onPressed: onDone,
                  icon: Icon(
                    counter
                        ? Symbols.add_rounded
                        : Symbols.check_circle_rounded,
                  ),
                  label: Text(counter ? l10n.checkIn : l10n.swipeDone),
                ),
              ),
            if (canCheckIn(task, now) && canSkip(task, now))
              const SizedBox(width: 8),
            if (canSkip(task, now))
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSkip,
                  icon: const Icon(Symbols.remove_circle_outline_rounded),
                  label: Text(l10n.swipeSkip),
                ),
              ),
            // A missed habit can still be logged; a resolved one can be undone.
            if (canCorrectMiss(task))
              Expanded(
                child: FilledButton.icon(
                  onPressed: onCorrectMiss,
                  icon: const Icon(Symbols.check_circle_rounded),
                  label: Text(l10n.markDoneAnyway),
                ),
              ),
            if (showReopen)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReopen,
                  icon: const Icon(Symbols.undo_rounded),
                  label: Text(l10n.reopenTask),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The series' Times section as a sheet; Save returns the goal.
class _GoalSheet extends StatefulWidget {
  const _GoalSheet({
    required this.initial,
    required this.unit,
    required this.spanDays,
  });
  final Goal initial;
  final String unit;
  final int spanDays;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late Goal _goal = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, viewInsets + 16),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.timesSection,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              GoalEditor(
                value: _goal,
                unit: widget.unit,
                spanDays: widget.spanDays,
                onChanged: (g) => setState(() => _goal = g),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_goal),
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

/// A counter's check-ins this cycle (§3.7): when each happened, a ✕ to take
/// one back, and "Add a forgotten check-in" while the record can still take
/// one (a Skipped cycle was declined; one-offs don't count).
class _CheckInList extends StatelessWidget {
  const _CheckInList({
    required this.task,
    required this.now,
    required this.onRemove,
    required this.onAdd,
  });

  final Task task;
  final DateTime now;
  final ValueChanged<DateTime> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final canAdd =
        task.templateId != null &&
        task.status != TaskStatus.skipped &&
        !task.goal.capped(task.count);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.checkInsSection.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: scheme.outline,
            fontWeight: FontWeight.w700,
            letterSpacing: .6,
          ),
        ),
        if (task.checkIns.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              l10n.noCheckInsYet,
              style: TextStyle(color: scheme.outline),
            ),
          ),
        for (final at in task.checkIns.reversed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Symbols.check_circle_rounded, color: scheme.tertiary),
            title: Text(
              '${DateFormat.MMMEd(locale).format(at)} · '
              '${DateFormat.Hm(locale).format(at)}',
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            trailing: task.status == TaskStatus.skipped
                ? null
                : IconButton(
                    tooltip: l10n.removeCheckIn,
                    icon: const Icon(Symbols.close_rounded),
                    onPressed: () => onRemove(at),
                  ),
          ),
        if (canAdd)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Symbols.add_circle_rounded, color: scheme.primary),
            title: Text(
              l10n.addForgottenCheckIn,
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            onTap: onAdd,
          ),
      ],
    );
  }
}
