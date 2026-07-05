import 'recurrence.dart';
import 'task.dart';
import 'window_rule.dart';

/// The Template — the recurring factory (design-concept §3). Carries the
/// recurrence, the window rule, and the defaults stamped onto each generated
/// Task. Never completed, no status. (One-offs are template-less Tasks.)
class Template {
  const Template({
    this.id,
    required this.name,
    this.note,
    required this.recurrence,
    this.windowRule = const UntilNextOccurrence(),
    this.paused = false,
    this.resumeOn,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final String? note;
  final Recurrence recurrence;
  final WindowRule windowRule;

  /// Pause (§3.5): while paused the engine generates no new instances.
  final bool paused;

  /// The resume point (§3.5). While paused: the optional auto-resume date
  /// (null = indefinite). It also serves as the engine's **generation floor** —
  /// back-fill never materialises occurrences that ended before it, so a
  /// paused stretch produces no retroactive Misses. The repository stamps it
  /// with "now" on a manual unpause for the same reason.
  final DateTime? resumeOn;

  final DateTime createdAt;

  /// Whether the template should generate at [now] — paused unless a resume date
  /// has arrived. (Global Vacation is checked separately, at the engine level.)
  bool generatesAt(DateTime now) {
    if (!paused) return true;
    return resumeOn != null && !now.isBefore(resumeOn!);
  }

  /// Materialise the Task for [occurrence], applying the window rule.
  /// [nextOccurrence] feeds the default (until-next) window. [now] stamps
  /// `createdAt` on the new instance.
  Task materialize(
    DateTime occurrence,
    DateTime nextOccurrence, {
    required DateTime now,
  }) {
    final w = windowRule.resolve(occurrence, nextOccurrence);
    return Task(
      templateId: id,
      name: name,
      note: note,
      start: w.start,
      end: w.end,
      occurrence: DateTime(occurrence.year, occurrence.month, occurrence.day),
      createdAt: now,
    );
  }
}
