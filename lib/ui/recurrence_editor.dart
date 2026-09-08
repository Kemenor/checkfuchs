import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../domain/recurrence.dart';
import '../l10n/app_localizations.dart';
import 'recurrence_summary_l10n.dart';

/// The recurrence editor (design mockup 06-recurrence): segmented frequency
/// (Off = one-off), an every-N stepper, per-frequency controls, and the live
/// localized summary banner. Emits a `Recurrence?` (null = doesn't repeat)
/// on every change.
class RecurrenceEditor extends StatefulWidget {
  const RecurrenceEditor({
    super.key,
    required this.anchor,
    required this.onChanged,
    this.initial,
  });

  /// The reference date intervals count from (typically the task's start/today).
  final DateTime anchor;
  final ValueChanged<Recurrence?> onChanged;

  /// Pre-fill from an existing rule (editing a series); null = start at "Off".
  final Recurrence? initial;

  @override
  State<RecurrenceEditor> createState() => _RecurrenceEditorState();
}

class _RecurrenceEditorState extends State<RecurrenceEditor> {
  Freq? _freq; // null = Off (doesn't repeat)
  int _interval = 1;
  late DateTime _anchor = widget.anchor;
  late Set<Weekday> _weekdays = {Weekday.fromDateTime(widget.anchor)};
  late int _monthDay = widget.anchor.day;
  bool _lastDay = false;
  late int _month = widget.anchor.month;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    if (r == null) return;
    _freq = r.freq;
    _interval = r.interval;
    _anchor = DateTime(r.anchor.year, r.anchor.month, r.anchor.day);
    if (r.byWeekday.isNotEmpty) _weekdays = {...r.byWeekday};
    final md = r.byMonthDay;
    if (md != null) {
      if (md == lastDayOfMonth) {
        _lastDay = true;
      } else {
        _monthDay = md;
      }
    }
    if (r.byMonth != null) _month = r.byMonth!;
  }

  Recurrence? _build() {
    final a = _anchor;
    return switch (_freq) {
      null => null,
      Freq.daily => Recurrence.daily(a, interval: _interval),
      Freq.weekly => Recurrence.weekly(
        a,
        interval: _interval,
        on: _weekdays.isEmpty ? {Weekday.fromDateTime(a)} : _weekdays,
      ),
      Freq.monthly => Recurrence.monthly(
        a,
        interval: _interval,
        day: _lastDay ? lastDayOfMonth : _monthDay,
      ),
      Freq.yearly => Recurrence.yearly(
        a,
        interval: _interval,
        month: _month,
        day: _monthDay,
      ),
    };
  }

  void _emit() => widget.onChanged(_build());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Live summary banner.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                Symbols.event_repeat_rounded,
                color: scheme.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  localizedRecurrenceSummary(context, _build()),
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: -1, label: Text(l10n.freqOff)),
            ButtonSegment(value: 0, label: Text(l10n.freqDay)),
            ButtonSegment(value: 1, label: Text(l10n.freqWeek)),
            ButtonSegment(value: 2, label: Text(l10n.freqMonth)),
            ButtonSegment(value: 3, label: Text(l10n.freqYear)),
          ],
          selected: {_freq == null ? -1 : _freq!.index},
          onSelectionChanged: (s) => setState(() {
            final v = s.first;
            _freq = v == -1 ? null : Freq.values[v];
            _emit();
          }),
        ),

        if (_freq != null) ...[
          const SizedBox(height: 18),
          _EveryStepper(
            value: _interval,
            unit: _unitLabel(l10n, _freq!, _interval),
            onChanged: (v) => setState(() {
              _interval = v;
              _emit();
            }),
          ),
        ],

        if (_freq == Freq.weekly) ...[
          const SizedBox(height: 16),
          _WeekdayPicker(
            selected: _weekdays,
            onChanged: (s) => setState(() {
              _weekdays = s;
              _emit();
            }),
          ),
        ],

        if (_freq == Freq.monthly) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AnimatedOpacity(
                  opacity: _lastDay ? .4 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: _EveryStepper(
                    label: l10n.onDay,
                    value: _monthDay,
                    min: 1,
                    max: 31,
                    unit: '',
                    onChanged: _lastDay
                        ? null
                        : (v) => setState(() {
                            _monthDay = v;
                            _emit();
                          }),
                  ),
                ),
              ),
              FilterChip(
                label: Text(l10n.lastDay),
                selected: _lastDay,
                onSelected: (v) => setState(() {
                  _lastDay = v;
                  _emit();
                }),
              ),
            ],
          ),
        ],

        if (_freq == Freq.yearly) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _month,
                  decoration: InputDecoration(
                    labelText: l10n.monthLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(
                        value: m,
                        child: Text(localizedMonthName(locale, m)),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    _month = v ?? _month;
                    _emit();
                  }),
                ),
              ),
              const SizedBox(width: 12),
              _EveryStepper(
                label: l10n.dayLabel,
                value: _monthDay,
                min: 1,
                max: 31,
                unit: '',
                onChanged: (v) => setState(() {
                  _monthDay = v;
                  _emit();
                }),
              ),
            ],
          ),
        ],

        // The Starts (anchor) row (DESIGN_SYSTEM §3.5) — load-bearing for any
        // interval > 1 ("every other Saturday" counts from here).
        if (_freq != null) ...[
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Symbols.today_rounded),
            title: Text(l10n.starts),
            trailing: Text(
              DateFormat.yMMMd(locale).format(_anchor),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _anchor,
                firstDate: DateTime(_anchor.year - 3),
                lastDate: DateTime(_anchor.year + 3),
              );
              if (picked != null) {
                setState(() {
                  _anchor = DateTime(picked.year, picked.month, picked.day);
                  _emit();
                });
              }
            },
          ),
        ],
      ],
    );
  }
}

String _unitLabel(AppLocalizations l10n, Freq f, int n) => switch (f) {
  Freq.daily => l10n.unitDays(n),
  Freq.weekly => l10n.unitWeeks(n),
  Freq.monthly => l10n.unitMonths(n),
  Freq.yearly => l10n.unitYears(n),
};

class _EveryStepper extends StatelessWidget {
  const _EveryStepper({
    required this.value,
    required this.unit,
    required this.onChanged,
    this.label,
    this.min = 1,
    this.max = 99,
  });

  final int value;
  final String unit;

  /// Row label; null = the localized "Every".
  final String? label;
  final int min;
  final int max;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Text(
          label ?? l10n.every,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 12),
        IconButton.outlined(
          tooltip: l10n.decrease,
          onPressed: (onChanged != null && value > min)
              ? () => onChanged!(value - 1)
              : null,
          icon: const Icon(Symbols.remove_rounded),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        IconButton.outlined(
          tooltip: l10n.increase,
          onPressed: (onChanged != null && value < max)
              ? () => onChanged!(value + 1)
              : null,
          icon: const Icon(Symbols.add_rounded),
        ),
        if (unit.isNotEmpty) ...[
          const SizedBox(width: 10),
          Text(
            unit,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ],
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onChanged});

  final Set<Weekday> selected;
  final ValueChanged<Set<Weekday>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.weekdayInitialMon,
      l10n.weekdayInitialTue,
      l10n.weekdayInitialWed,
      l10n.weekdayInitialThu,
      l10n.weekdayInitialFri,
      l10n.weekdayInitialSat,
      l10n.weekdayInitialSun,
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final wd in Weekday.values)
          ChoiceChip(
            label: Text(labels[wd.index]),
            selected: selected.contains(wd),
            onSelected: (on) {
              final next = {...selected};
              on ? next.add(wd) : next.remove(wd);
              onChanged(next);
            },
          ),
      ],
    );
  }
}
