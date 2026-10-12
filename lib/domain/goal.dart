/// The Goal — how many check-ins a habit's cycle wants (design-concept §3.7).
/// Every habit has one; an ordinary habit's is 1 of 1. Stamped from the
/// Template onto each generated Task, so a Task can resolve itself and the
/// reminder scheduler (which only sees Tasks) can read [remindTill].
library;

import 'recurrence.dart';
import 'window_rule.dart';

/// When a counter's pending reminders stop: once it is met (`min`), or only
/// once it reaches its cap (`max` — with no limit, when the window closes).
enum RemindTill { min, max }

class Goal {
  const Goal({
    this.min = 1,
    this.max = 1,
    this.oncePerDay = false,
    this.remindTill = RemindTill.min,
  }) : assert(min >= 1, 'min must be >= 1'),
       assert(max == null || max >= min, 'max must be >= min');

  /// A fixed goal: exactly [n] check-ins (at least = at most).
  const Goal.times(int n, {bool oncePerDay = false})
    : this(min: n, max: n, oncePerDay: oncePerDay);

  /// The ordinary habit: one check-in and it is Done.
  static const single = Goal();

  /// Check-ins that meet the cycle.
  final int min;

  /// The cap — reaching it makes the Task Done. Null = no limit.
  final int? max;

  /// At most one check-in per calendar day.
  final bool oncePerDay;

  final RemindTill remindTill;

  /// The ordinary 1-of-1 habit (and every one-off).
  bool get isSingle => min == 1 && max == 1;

  /// At most differs from at least (a span, or no limit) — the only shape
  /// where [remindTill] matters.
  bool get isRange => max != min;

  /// Whether [count] check-ins have reached the cap.
  bool capped(int count) => max != null && count >= max!;

  /// This goal, valid for a window touching [spanDays] calendar days (§3.7,
  /// §7): `oncePerDay` only makes sense across more than one day and needs
  /// `min ≤ spanDays` — otherwise it is dropped rather than leaving a cycle
  /// that can never be met.
  Goal fitTo(int spanDays) => oncePerDay && (spanDays < 2 || min > spanDays)
      ? copyWith(oncePerDay: false)
      : this;

  static const _unset = Object();

  Goal copyWith({
    int? min,
    Object? max = _unset,
    bool? oncePerDay,
    RemindTill? remindTill,
  }) => Goal(
    min: min ?? this.min,
    max: identical(max, _unset) ? this.max : max as int?,
    oncePerDay: oncePerDay ?? this.oncePerDay,
    remindTill: remindTill ?? this.remindTill,
  );

  @override
  bool operator ==(Object other) =>
      other is Goal &&
      other.min == min &&
      other.max == max &&
      other.oncePerDay == oncePerDay &&
      other.remindTill == remindTill;

  @override
  int get hashCode => Object.hash(min, max, oncePerDay, remindTill);

  @override
  String toString() =>
      'Goal($min–${max ?? '∞'}${oncePerDay ? ', once a day' : ''}, '
      'remind till ${remindTill.name})';
}

/// How many calendar days one cycle's window touches — a daily all-day
/// window 1, a weekly until-next window 7, Sat–Sun 2. Decides whether "once a
/// day" is offered and what it allows ([Goal.fitTo]).
int windowSpanDays(Recurrence r, WindowRule w) {
  final occ = occurrenceOnOrAfter(r, r.anchor);
  final win = w.resolve(occ, occurrenceAfter(r, occ));
  // The end is exclusive: a window ending at midnight doesn't touch that day.
  final last = win.end.subtract(const Duration(microseconds: 1));
  final from = DateTime.utc(win.start.year, win.start.month, win.start.day);
  final to = DateTime.utc(last.year, last.month, last.day);
  return to.difference(from).inDays + 1;
}
