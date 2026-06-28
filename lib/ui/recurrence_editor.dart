import 'package:flutter/material.dart';

import '../domain/recurrence.dart';
import '../domain/recurrence_summary.dart';

/// The recurrence editor (design mockup 06-recurrence): segmented frequency
/// (Off = one-off), an every-N stepper, per-frequency controls, and the live
/// plain-English summary banner. Emits a `Recurrence?` (null = doesn't repeat)
/// on every change.
class RecurrenceEditor extends StatefulWidget {
  const RecurrenceEditor({
    super.key,
    required this.anchor,
    required this.onChanged,
  });

  /// The reference date intervals count from (typically the task's start/today).
  final DateTime anchor;
  final ValueChanged<Recurrence?> onChanged;

  @override
  State<RecurrenceEditor> createState() => _RecurrenceEditorState();
}

class _RecurrenceEditorState extends State<RecurrenceEditor> {
  Freq? _freq; // null = Off (doesn't repeat)
  int _interval = 1;
  late Set<Weekday> _weekdays = {Weekday.fromDateTime(widget.anchor)};
  late int _monthDay = widget.anchor.day;
  bool _lastDay = false;
  late int _month = widget.anchor.month;

  Recurrence? _build() {
    final a = widget.anchor;
    return switch (_freq) {
      null => null,
      Freq.daily => Recurrence.daily(a, interval: _interval),
      Freq.weekly => Recurrence.weekly(a,
          interval: _interval,
          on: _weekdays.isEmpty ? {Weekday.fromDateTime(a)} : _weekdays),
      Freq.monthly => Recurrence.monthly(a,
          interval: _interval, day: _lastDay ? lastDayOfMonth : _monthDay),
      Freq.yearly =>
        Recurrence.yearly(a, interval: _interval, month: _month, day: _monthDay),
    };
  }

  void _emit() => widget.onChanged(_build());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              Icon(Icons.event_repeat, color: scheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  recurrenceSummary(_build()),
                  style: TextStyle(
                      color: scheme.primary, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: -1, label: Text('Off')),
            ButtonSegment(value: 0, label: Text('Day')),
            ButtonSegment(value: 1, label: Text('Week')),
            ButtonSegment(value: 2, label: Text('Month')),
            ButtonSegment(value: 3, label: Text('Year')),
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
            unit: _unitLabel(_freq!, _interval),
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
                    label: 'On day',
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
                label: const Text('Last day'),
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
                  decoration: const InputDecoration(
                      labelText: 'Month', border: OutlineInputBorder()),
                  items: [
                    for (var m = 1; m <= 12; m++)
                      DropdownMenuItem(value: m, child: Text(_monthName(m))),
                  ],
                  onChanged: (v) => setState(() {
                    _month = v ?? _month;
                    _emit();
                  }),
                ),
              ),
              const SizedBox(width: 12),
              _EveryStepper(
                label: 'Day',
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
      ],
    );
  }
}

String _unitLabel(Freq f, int n) {
  final plural = n != 1;
  return switch (f) {
    Freq.daily => plural ? 'days' : 'day',
    Freq.weekly => plural ? 'weeks' : 'week',
    Freq.monthly => plural ? 'months' : 'month',
    Freq.yearly => plural ? 'years' : 'year',
  };
}

String _monthName(int m) => const [
      'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December',
    ][m - 1];

class _EveryStepper extends StatelessWidget {
  const _EveryStepper({
    required this.value,
    required this.unit,
    required this.onChanged,
    this.label = 'Every',
    this.min = 1,
    this.max = 99,
  });

  final int value;
  final String unit;
  final String label;
  final int min;
  final int max;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        IconButton.outlined(
          onPressed:
              (onChanged != null && value > min) ? () => onChanged!(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 36,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ),
        IconButton.outlined(
          onPressed:
              (onChanged != null && value < max) ? () => onChanged!(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
        if (unit.isNotEmpty) ...[
          const SizedBox(width: 10),
          Text(unit, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        ],
      ],
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onChanged});

  final Set<Weekday> selected;
  final ValueChanged<Set<Weekday>> onChanged;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final wd in Weekday.values)
          ChoiceChip(
            label: Text(_labels[wd.index]),
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
