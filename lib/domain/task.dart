/// The Task — the only object with a completion status (design-concept §2) — and
/// its pure state machine. No I/O: every function is `(task, now) → task/bool`,
/// so the whole lifecycle is unit-testable against a [FixedClock].
library;

import 'goal.dart';
import 'notification.dart';
import 'window_rule.dart';

/// The four live-or-terminal states (§2.2). Only `open` is non-terminal.
enum TaskStatus { open, done, skipped, missed }

/// Where `now` sits relative to a Task's window — **derived, never stored** (§2.3).
enum TaskPhase {
  /// `now < start` — exists but not yet actionable.
  pending,

  /// within the window (or unbounded) and still open — actionable.
  active,

  /// `now > end` while still open — due to become `Missed`.
  expired,
}

class Task {
  const Task({
    this.id,
    this.templateId,
    required this.name,
    this.note,
    this.status = TaskStatus.open,
    this.start,
    this.end,
    this.occurrence,
    required this.createdAt,
    this.resolvedAt,
    this.notifications = const [],
    this.bands,
    this.goal = Goal.single,
    this.checkIns = const [],
  });

  final int? id;

  /// The generating Template; null = a standalone one-off (§3, §2.1).
  final int? templateId;
  final String name;
  final String? note;
  final TaskStatus status;

  /// Window (§2.3). `start` absent ⇒ active immediately; `end` absent ⇒ endless
  /// & unfailable (only `Done`/`Skipped`, never `Missed`).
  final DateTime? start;
  final DateTime? end;

  /// The occurrence date this instance fills (for a generated Task) — used to
  /// match stored tasks to projection slots (§3.4). Null for standalone one-offs.
  final DateTime? occurrence;

  final DateTime createdAt;

  /// When it went terminal; null while open. Required for analytics (§2.1).
  final DateTime? resolvedAt;

  /// Reminders on this instance (§2.4). Stamped from the Template's defaults
  /// at materialisation; editable per instance. All **discrete** — the
  /// reactive layer schedules only open tasks, so resolving one cancels its
  /// pings by construction.
  final List<TaskNotification> notifications;

  /// Active bands *within* `start`…`end`, repeating each civil day of the
  /// window ("morning or evening"). Null = the whole span is active. Only the
  /// phase reads this; `start`/`end` stay the envelope everything else uses.
  final List<Band>? bands;

  /// How many check-ins the cycle wants (§3.7) — stamped from the Template;
  /// 1 of 1 for every ordinary habit and one-off.
  final Goal goal;

  /// The check-ins toward [goal], ascending (§2.1). For a 1-of-1 Task, its
  /// single Done. Rows resolved before check-ins existed have none — see
  /// [doneUnits].
  final List<DateTime> checkIns;

  bool get isOpen => status == TaskStatus.open;
  bool get isTerminal => !isOpen;

  int get count => checkIns.length;

  /// Derived (§3.7): enough check-ins that the cycle can no longer Miss.
  bool get isMet => count >= goal.min;

  /// A habit wanting more than one check-in.
  bool get isCounter => !goal.isSingle;

  /// Analytics units (§8): every check-in is one *done*. A Done without
  /// check-ins (resolved before they existed) still counts as one.
  int get doneUnits =>
      checkIns.isEmpty && status == TaskStatus.done ? 1 : count;

  /// Analytics units (§8): every check-in short of `min` when the cycle
  /// closed is one *missed*. Derived, never stored.
  int get missedUnits =>
      status == TaskStatus.missed && count < goal.min ? goal.min - count : 0;

  /// Nullable fields use a sentinel default so they can be *cleared* by passing
  /// an explicit `null` (e.g. removing a due date, or nulling `resolvedAt` for
  /// a Missed→Done correction) — `?? this.x` could never express that.
  static const _unset = Object();

  Task copyWith({
    int? id,
    Object? templateId = _unset,
    String? name,
    Object? note = _unset,
    TaskStatus? status,
    Object? start = _unset,
    Object? end = _unset,
    Object? occurrence = _unset,
    DateTime? createdAt,
    Object? resolvedAt = _unset,
    List<TaskNotification>? notifications,
    Object? bands = _unset,
    Goal? goal,
    List<DateTime>? checkIns,
  }) {
    return Task(
      id: id ?? this.id,
      templateId: identical(templateId, _unset)
          ? this.templateId
          : templateId as int?,
      name: name ?? this.name,
      note: identical(note, _unset) ? this.note : note as String?,
      status: status ?? this.status,
      start: identical(start, _unset) ? this.start : start as DateTime?,
      end: identical(end, _unset) ? this.end : end as DateTime?,
      occurrence: identical(occurrence, _unset)
          ? this.occurrence
          : occurrence as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: identical(resolvedAt, _unset)
          ? this.resolvedAt
          : resolvedAt as DateTime?,
      notifications: notifications ?? this.notifications,
      bands: identical(bands, _unset) ? this.bands : bands as List<Band>?,
      goal: goal ?? this.goal,
      checkIns: checkIns ?? this.checkIns,
    );
  }

  static bool _sameNotifications(
    List<TaskNotification> a,
    List<TaskNotification> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is Task &&
      other.id == id &&
      other.templateId == templateId &&
      other.name == name &&
      other.note == note &&
      other.status == status &&
      other.start == start &&
      other.end == end &&
      other.occurrence == occurrence &&
      other.createdAt == createdAt &&
      other.resolvedAt == resolvedAt &&
      _sameNotifications(other.notifications, notifications) &&
      _sameBands(other.bands, bands) &&
      other.goal == goal &&
      _sameCheckIns(other.checkIns, checkIns);

  static bool _sameCheckIns(List<DateTime> a, List<DateTime> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameBands(List<Band>? a, List<Band>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    templateId,
    name,
    note,
    status,
    start,
    end,
    occurrence,
    createdAt,
    resolvedAt,
    Object.hashAll(notifications),
    bands == null ? null : Object.hashAll(bands!),
    goal,
    Object.hashAll(checkIns),
  );

  @override
  String toString() =>
      'Task(#$id "$name" $status start:$start end:$end'
      '${goal.isSingle ? '' : ' $count/${goal.min}–${goal.max ?? '∞'}'})';
}

// ---------------------------------------------------------------------------
// State machine — pure transitions over (task, now)
// ---------------------------------------------------------------------------

/// Where `now` sits in the task's window. Independent of [TaskStatus]; it only
/// describes time. (`start` null ⇒ never pending; `end` null ⇒ never expired.)
/// With [Task.bands], the gaps between bands read as `pending` — the window
/// hasn't expired, but the task isn't actionable right now.
TaskPhase phaseOf(Task t, DateTime now) {
  if (t.start != null && now.isBefore(t.start!)) return TaskPhase.pending;
  if (t.end != null && now.isAfter(t.end!)) return TaskPhase.expired;
  final bands = t.bands;
  if (bands != null && bands.isNotEmpty && !bands.any((b) => b.contains(now))) {
    return TaskPhase.pending;
  }
  return TaskPhase.active;
}

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whether [t] already holds a check-in on [day]'s calendar day.
bool checkedInOn(Task t, DateTime day) {
  final key = _dayOf(day);
  return t.checkIns.any((c) => _dayOf(c) == key);
}

/// Room for one more check-in at [at]: below the cap and, with `oncePerDay`,
/// none yet on that calendar day.
bool _roomFor(Task t, DateTime at) =>
    !t.goal.capped(t.count) && !(t.goal.oncePerDay && checkedInOn(t, at));

Task _withCheckIn(Task t, DateTime at) =>
    t.copyWith(checkIns: [...t.checkIns, at]..sort());

/// The ring tap — one check-in at [now] (§3.7). Allowed **only while Active**
/// (§2.5), below the cap, and not twice on one day with `oncePerDay`.
bool canCheckIn(Task t, DateTime now) =>
    t.isOpen && phaseOf(t, now) == TaskPhase.active && _roomFor(t, now);

/// Apply a check-in. A 1-of-1 Task goes straight to Done; a counter goes Done
/// at its cap and otherwise stays Open (met or not).
Task checkIn(Task t, DateTime now) {
  assert(canCheckIn(t, now), 'checkIn() requires an active task with room');
  return resolve(_withCheckIn(t, now), now);
}

/// `Skip` — user action, allowed while Open (Pending or Active), but not once
/// the window has expired (it's about to resolve) nor once met — a met cycle
/// can't fail, so there is nothing to decline (§3.7).
bool canSkip(Task t, DateTime now) =>
    t.isOpen && phaseOf(t, now) != TaskPhase.expired && !t.isMet;

/// Apply `Skip`. Check-ins already made stay on the record.
Task skip(Task t, DateTime now) {
  assert(canSkip(t, now), 'skip() requires an open, unmet, non-expired task');
  return t.copyWith(status: TaskStatus.skipped, resolvedAt: now);
}

bool _inWindow(Task t, DateTime at) =>
    (t.start == null || !at.isBefore(t.start!)) &&
    (t.end == null || !at.isAfter(t.end!));

/// A forgotten check-in, logged after the fact (§3.7 corrections, §11 q7): a
/// *habit* instance only — a logging fix, not doing it late — at a time
/// inside its window and not in the future. Works on an open, met, Done or
/// Missed instance alike; a Skipped one was declined.
bool canAddCheckIn(Task t, DateTime at, DateTime now) =>
    t.templateId != null &&
    t.status != TaskStatus.skipped &&
    !at.isAfter(now) &&
    _inWindow(t, at) &&
    _roomFor(t, at);

Task addCheckIn(Task t, DateTime at, DateTime now) {
  assert(
    canAddCheckIn(t, at, now),
    'addCheckIn() needs room inside the window',
  );
  return resolve(_withCheckIn(t, at), now);
}

/// Take one check-in back (the detail sheet's ✕), re-resolving: a Done below
/// its cap reopens while the window runs, an expired cycle that drops below
/// `min` becomes Missed.
bool canRemoveCheckIn(Task t, DateTime at) =>
    t.status != TaskStatus.skipped && t.checkIns.contains(at);

Task removeCheckIn(Task t, DateTime at, DateTime now) {
  assert(canRemoveCheckIn(t, at), 'removeCheckIn() needs that check-in');
  return resolve(t.copyWith(checkIns: [...t.checkIns]..remove(at)), now);
}

/// Missed → Done for a **1-of-1** habit — the ring tap on a missed row (§11
/// q7: a logging fix, not doing it late). A counter's correction needs a
/// time, so it goes through [addCheckIn] in the detail sheet instead. A
/// one-off's hard deadline stays irrevocable.
bool canCorrectMiss(Task t) =>
    t.status == TaskStatus.missed &&
    t.templateId != null &&
    t.goal.isSingle &&
    (t.end ?? t.resolvedAt) != null;

/// Apply the correction: a check-in at the window end — the latest instant
/// the habit could have been done inside its window — so analytics keep
/// reading it as an in-window completion, never as "done late".
Task correctMiss(Task t) {
  assert(canCorrectMiss(t), 'correctMiss() requires a missed 1-of-1 habit');
  final at = (t.end ?? t.resolvedAt)!;
  return resolve(_withCheckIn(t, at), at);
}

/// Undo a Done/Skip (a mis-tap, a mis-swipe). A Skip reopens; a Done gives
/// back its latest check-in (a Done from before check-ins simply reopens).
/// Either way the result is re-resolved, so an instance whose window has
/// meanwhile closed lands on Missed (or stays Done if still met) — truthful.
/// Missed is not undone this way: it's a *window* fact ([correctMiss],
/// [addCheckIn]).
bool canReopen(Task t) =>
    t.status == TaskStatus.done || t.status == TaskStatus.skipped;

Task reopen(Task t, DateTime now) {
  assert(canReopen(t), 'reopen() requires a done or skipped task');
  final open = t.copyWith(status: TaskStatus.open, resolvedAt: null);
  if (t.status == TaskStatus.skipped) return resolve(open, now);
  final ins = [...t.checkIns];
  if (ins.isNotEmpty) ins.removeLast();
  return resolve(open.copyWith(checkIns: ins), now);
}

/// Re-derive status from the check-ins and the goal (§3.7) — after any
/// check-in change or goal edit, and at expiry. Skipped is a decision and
/// stays. At the cap → Done (`resolvedAt` = the check-in that reached it);
/// window over → Done if met (`resolvedAt` = the last check-in, the one
/// automatic Done) else Missed (`resolvedAt` = window end); otherwise Open.
Task resolve(Task t, DateTime now) {
  if (t.status == TaskStatus.skipped) return t;
  final ins = t.checkIns;
  if (t.goal.capped(ins.length)) {
    return t.copyWith(
      status: TaskStatus.done,
      resolvedAt: ins[t.goal.max! - 1],
    );
  }
  final expired = t.end != null && now.isAfter(t.end!);
  if (expired) {
    return t.isMet
        ? t.copyWith(status: TaskStatus.done, resolvedAt: ins.last)
        : t.copyWith(status: TaskStatus.missed, resolvedAt: t.end);
  }
  return t.copyWith(status: TaskStatus.open, resolvedAt: null);
}

/// A goal edit reaching the running instance (§3.7, §5): an open Task takes
/// [goal] and is re-resolved at once. Terminal Tasks are history — null.
Task? applyGoal(Task t, Goal goal, DateTime now) =>
    t.isOpen ? resolve(t.copyWith(goal: goal), now) : null;

/// Auto-resolve an open task whose window has passed. Returns the updated
/// task, or `null` if nothing changes. Below `min` → `Missed` with
/// `resolvedAt` = the window **end** (when it actually failed), so
/// back-filling on a later open stays truthful; a met counter → `Done`.
Task? expireIfDue(Task t, DateTime now) {
  if (!t.isOpen || phaseOf(t, now) != TaskPhase.expired) return null;
  return resolve(t, now);
}
