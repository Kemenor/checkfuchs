import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../domain/goal.dart';
import '../domain/recurrence.dart';
import '../l10n/app_localizations.dart';
import 'goal_ring.dart';

/// The Times section (design-concept §3.7, mockup `10-counter.html`):
/// collapsed by default to one line — a single stepper setting a fixed goal
/// (at least = at most). "Range…" splits it into At least / At most + No
/// limit. "Once a day" shows once the goal is above 1 and the window spans
/// more than a day; "Remind until" only in range mode, where the two ends
/// differ. Emits a [Goal] on every change; 1 of 1 is an ordinary habit.
class GoalEditor extends StatefulWidget {
  const GoalEditor({
    super.key,
    required this.value,
    required this.unit,
    required this.spanDays,
    required this.onChanged,
  });

  final Goal value;

  /// "a day", "a week", … ([goalUnit]).
  final String unit;

  /// Calendar days one cycle's window touches ([windowSpanDays]).
  final int spanDays;
  final ValueChanged<Goal> onChanged;

  @override
  State<GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<GoalEditor> {
  /// Range mode is a view choice, not data: a fixed goal can be shown split.
  late bool _range = widget.value.isRange;

  /// The cap to restore when "No limit" is switched back off.
  late int _lastMax = widget.value.max ?? widget.value.min;

  static const _top = 99;

  Goal get _g => widget.value;

  /// Fitted on the way out: a goal "once a day" can't hold drops it (§7).
  void _emit(Goal g) => widget.onChanged(g.fitTo(widget.spanDays));

  void _setFixed(int n) => _emit(_g.copyWith(min: n, max: n));

  void _setMin(int n) {
    final max = _g.max;
    _emit(_g.copyWith(min: n, max: max != null && max < n ? n : max));
  }

  void _setMax(int n) {
    _lastMax = n;
    _emit(_g.copyWith(max: n));
  }

  void _toggleRange() {
    setState(() => _range = !_range);
    // Folding back: at most snaps to at least.
    if (!_range) _emit(_g.copyWith(max: _g.min));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final g = _g;
    final offerOncePerDay = widget.spanDays > 1 && !g.isSingle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The section title already says "Times": the fixed stepper needs
        // no label of its own. The chips sit on their own line so long
        // translations never squeeze the stepper.
        if (!_range)
          _Stepper(
            value: g.min,
            min: 1,
            max: _top,
            unit: widget.unit,
            onChanged: _setFixed,
          )
        else ...[
          _Stepper(
            label: l10n.goalAtLeast,
            value: g.min,
            min: 1,
            max: g.max ?? _top,
            unit: widget.unit,
            onChanged: _setMin,
          ),
          _Stepper(
            label: l10n.goalAtMost,
            value: g.max ?? _lastMax,
            min: g.min,
            max: _top,
            unit: widget.unit,
            onChanged: g.max == null ? null : _setMax,
          ),
        ],
        Wrap(
          spacing: 8,
          children: [
            if (!_range)
              ActionChip(label: Text(l10n.goalRange), onPressed: _toggleRange)
            else ...[
              FilterChip(
                label: Text(l10n.goalRangeOn),
                selected: true,
                showCheckmark: false,
                onSelected: (_) => _toggleRange(),
              ),
              FilterChip(
                label: Text(l10n.goalNoLimit),
                selected: g.max == null,
                onSelected: (on) => _emit(
                  g.copyWith(
                    max: on ? null : (_lastMax < g.min ? g.min : _lastMax),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (offerOncePerDay)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.goalOncePerDay),
            subtitle: Text(l10n.goalOncePerDayHint),
            value: g.oncePerDay,
            // More than one check-in per day would be needed to meet it.
            onChanged: g.min > widget.spanDays
                ? null
                : (v) => _emit(g.copyWith(oncePerDay: v)),
          ),
        if (_range && g.isRange) ...[
          const SizedBox(height: 4),
          Text(
            l10n.goalRemindUntil,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            l10n.goalRemindUntilHint,
            style: TextStyle(color: scheme.outline, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SegmentedButton<RemindTill>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: RemindTill.min,
                label: Text(l10n.goalRemindMin),
              ),
              ButtonSegment(
                value: RemindTill.max,
                label: Text(l10n.goalRemindMax),
              ),
            ],
            selected: {g.remindTill},
            onSelectionChanged: (s) => _emit(g.copyWith(remindTill: s.first)),
          ),
        ],
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
  });

  /// Null for the fixed stepper (the section title names it).
  final String? label;
  final int value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final enabled = onChanged != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (label != null)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 88),
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  label!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          IconButton.outlined(
            tooltip: l10n.decrease,
            onPressed: enabled && value > min
                ? () => onChanged!(value - 1)
                : null,
            icon: const Icon(Symbols.remove_rounded),
          ),
          SizedBox(
            width: 32,
            child: Text(
              enabled ? '$value' : '–',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton.outlined(
            tooltip: l10n.increase,
            onPressed: enabled && value < max
                ? () => onChanged!(value + 1)
                : null,
            icon: const Icon(Symbols.add_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              unit,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}

/// "a day", "a week", "a month", "a year" — or "per cycle" for every-N rules.
String goalUnit(AppLocalizations l10n, Recurrence r) => r.interval > 1
    ? l10n.goalUnitCycle
    : switch (r.freq) {
        Freq.daily => l10n.goalUnitDay,
        Freq.weekly => l10n.goalUnitWeek,
        Freq.monthly => l10n.goalUnitMonth,
        Freq.yearly => l10n.goalUnitYear,
      };

/// The goal clause of the repeat banner: "2 times", "2–3 times, once a day",
/// "at least 8 times"; empty for an ordinary 1-of-1 habit.
String goalBannerClause(AppLocalizations l10n, Goal g) {
  if (g.isSingle) return '';
  final times = g.max == null
      ? l10n.goalSummaryAtLeast(g.min)
      : l10n.goalSummaryTimes(goalSpan(g));
  return g.oncePerDay ? '$times, ${l10n.goalSummaryOncePerDay}' : times;
}

/// The detail sheet's Times row: "Once", "2 a day", "2–3 a week, once a day
/// · remind until 2".
String goalRowSummary(AppLocalizations l10n, Goal g, String unit) {
  if (g.isSingle) return l10n.goalOnce;
  final parts = StringBuffer('${goalSpan(g)} $unit');
  if (g.oncePerDay) parts.write(', ${l10n.goalSummaryOncePerDay}');
  if (g.isRange) {
    parts.write(' · ');
    parts.write(switch ((g.remindTill, g.max)) {
      (RemindTill.min, _) => l10n.goalRowRemindUntil(g.min),
      (RemindTill.max, final int max) => l10n.goalRowRemindUntil(max),
      (RemindTill.max, null) => l10n.goalRowRemindUntilClose,
    });
  }
  return parts.toString();
}
