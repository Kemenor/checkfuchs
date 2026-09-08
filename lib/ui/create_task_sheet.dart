import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/db/database.dart';
import '../domain/notification.dart';
import '../domain/recurrence.dart';
import '../domain/task.dart';
import '../domain/template.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'recurrence_editor.dart';
import 'reminder_editor.dart';
import 'window_choice.dart';
import 'window_editor.dart';

final _viewLensesProvider = StreamProvider.autoDispose
    .family<List<LensRow>, int>(
      (ref, viewId) => ref
          .watch(viewRepositoryProvider)
          .watchViewLenses(viewId)
          .map((entries) => [for (final e in entries) e.lens]),
    );

/// Create a task or habit (Phase 3): name + lens (the bucket it lives in —
/// only this view's lenses are offered, preselected to [lensId] when the
/// sheet was opened from a lens card's +) + recurrence (Off = one-off) + an
/// active-window picker. A recurrence makes a Template; "Off" makes a
/// one-off Task. Reconciles so the first instance appears immediately.
Future<void> showCreateTaskSheet(
  BuildContext context,
  WidgetRef ref, {
  int? viewId,
  int? lensId,
  Recurrence? initialRecurrence,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CreateTaskSheet(
      viewId: viewId,
      lensId: lensId,
      initialRecurrence: initialRecurrence,
    ),
  );
}

class _CreateTaskSheet extends ConsumerStatefulWidget {
  const _CreateTaskSheet({this.viewId, this.lensId, this.initialRecurrence});

  /// Preset repeat rule — the first-launch "Start clean" opens the sheet as
  /// a daily habit (the carrier), so the first thing created keeps the app
  /// opening every day unless the user says otherwise.
  final Recurrence? initialRecurrence;

  final int? viewId;
  final int? lensId;

  @override
  ConsumerState<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends ConsumerState<_CreateTaskSheet> {
  final _controller = TextEditingController();
  late Recurrence? _recurrence = widget.initialRecurrence;
  WindowSelection _window = WindowSelection.anytime;
  List<TaskNotification> _notifications = const [];
  late Set<int> _lensIds = {if (widget.lensId != null) widget.lensId!};
  DateTime? _startDate;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    // Default bucket when none was preselected: the first lens of the view
    // the sheet was opened from — or, when that view has no lens yet, the
    // first lens overall (a task must land somewhere visible).
    if (_lensIds.isEmpty) {
      final repo = ref.read(viewRepositoryProvider);
      final viewId = widget.viewId;
      final fromView = viewId == null
          ? Future.value(const <LensRow>[])
          : repo
                .watchViewLenses(viewId)
                .first
                .then((e) => [for (final x in e) x.lens]);
      fromView.then((lenses) async {
        final pick = lenses.isNotEmpty
            ? lenses
            : await repo.watchAllLenses().first;
        if (mounted && _lensIds.isEmpty && pick.isNotEmpty) {
          setState(() => _lensIds = {pick.first.id});
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The lenses to offer as chips, and whether they lie outside the current
  /// view (it has none of its own — the task would otherwise vanish into a
  /// lens the user can't see from here).
  (List<LensRow>?, bool) _lensChoices(WidgetRef ref) {
    final all = ref.watch(allLensesProvider).asData?.value;
    final viewId = widget.viewId;
    if (viewId == null) return (all, false);
    final inView = ref.watch(_viewLensesProvider(viewId)).asData?.value;
    if (inView == null) return (null, false);
    if (inView.isEmpty) return (all, true);
    return (inView, false);
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(taskRepositoryProvider);
    final now = ref.read(clockProvider).now();

    final notifications = _notifications;
    if (_recurrence != null) {
      await repo.createTemplate(
        Template(
          name: name,
          recurrence: _recurrence!,
          windowRule: _window.toRule(),
          createdAt: now,
          notifications: notifications,
        ),
        lensIds: _lensIds,
      );
    } else {
      final (start, end) = _window.datedWindow(now, _startDate, _dueDate);
      await repo.createTask(
        Task(
          name: name,
          start: start,
          end: end,
          createdAt: now,
          notifications: notifications,
          // Only a window with gaps needs bands; the envelope covers the rest.
          bands: _window.hasGaps ? _window.bands : null,
        ),
        lensIds: _lensIds,
      );
    }
    await repo.reconcileAll(now);
    if (notifications.isNotEmpty) await ensureNotificationPermission(ref);
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.newTask, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.nameLabel,
                  hintText: l10n.taskNameHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              // The buckets: which lenses this task lives in (concept §4.6 —
              // membership is data; views merely arrange lenses). Multi-select,
              // never empty (a task in no lens is invisible). Scoped to the
              // current view's lenses — the detail sheet can move a task
              // anywhere later.
              ...switch (_lensChoices(ref)) {
                (null, _) => const [],
                // One lens and it's in this view: nothing to choose.
                (final lenses?, false) when lenses.length <= 1 => const [],
                (final lenses?, final outsideView) => [
                  if (outsideView) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.lensOutsideViewHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _SectionLabel(l10n.lensSection),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final lens in lenses)
                        FilterChip(
                          label: Text(lens.name),
                          selected: _lensIds.contains(lens.id),
                          onSelected: (on) => setState(() {
                            if (on) {
                              _lensIds = {..._lensIds, lens.id};
                            } else if (_lensIds.length > 1) {
                              _lensIds = {..._lensIds}..remove(lens.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
              },
              const SizedBox(height: 20),
              _SectionLabel(l10n.activeWindowSection),
              const SizedBox(height: 8),
              WindowEditor(
                value: _window,
                onChanged: (w) => setState(() => _window = w),
              ),
              // Date-pinned windows (one-offs only — a habit's window comes
              // from its slice rule): the slice shapes the hours, these pick
              // the days. "Month of May" = starts 1.5 + due 31.5; a bare due
              // date = open from now until the end of that day.
              if (_recurrence == null) ...[
                _DateRow(
                  icon: Symbols.today_rounded,
                  label: l10n.starts,
                  value: _startDate,
                  placeholder: l10n.startsNow,
                  today: anchor,
                  lastDate: _dueDate,
                  onChanged: (d) => setState(() => _startDate = d),
                ),
                _DateRow(
                  icon: Symbols.flag_rounded,
                  label: l10n.dueLabel,
                  value: _dueDate,
                  placeholder: l10n.noDueDate,
                  today: anchor,
                  firstDate: _startDate,
                  onChanged: (d) => setState(() => _dueDate = d),
                ),
              ],
              const SizedBox(height: 20),
              _SectionLabel(l10n.remindersSection),
              const SizedBox(height: 8),
              ReminderEditor(
                value: _notifications,
                // A series always has an occurrence day; a one-off needs a
                // due (or start) date for day-based reminders.
                hasDay:
                    _recurrence != null ||
                    _dueDate != null ||
                    _startDate != null,
                onChanged: (n) => setState(() => _notifications = n),
              ),
              const SizedBox(height: 20),
              _SectionLabel(l10n.repeatSection),
              const SizedBox(height: 10),
              RecurrenceEditor(
                anchor: anchor,
                initial: widget.initialRecurrence,
                onChanged: (r) => setState(() => _recurrence = r),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _controller.text.trim().isEmpty ? null : _save,
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

/// One optional date edge of the window: tap to pick, clear restores the
/// slice default.
class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.today,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  final IconData icon;
  final String label;
  final DateTime? value;
  final String placeholder;
  final DateTime today;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(
        value == null ? placeholder : DateFormat.yMMMEd(locale).format(value!),
        style: value == null ? TextStyle(color: scheme.outline) : null,
      ),
      trailing: value == null
          ? const Icon(Symbols.chevron_right_rounded)
          : IconButton(
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              icon: const Icon(Symbols.close_rounded),
              onPressed: () => onChanged(null),
            ),
      onTap: () async {
        final first = firstDate ?? today;
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? (first.isAfter(today) ? first : today),
          firstDate: first,
          lastDate: lastDate ?? DateTime(today.year + 5, 12, 31),
        );
        if (picked != null) onChanged(picked);
      },
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
