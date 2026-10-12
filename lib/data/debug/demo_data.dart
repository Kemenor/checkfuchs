import 'package:drift/drift.dart';

import '../../domain/goal.dart';
import '../../domain/lens.dart';
import '../../domain/notification.dart';
import '../../domain/recurrence.dart';
import '../../domain/task.dart';
import '../../domain/template.dart';
import '../../domain/window_rule.dart';
import '../../l10n/app_localizations.dart';
import '../db/database.dart';
import '../repositories/task_repository.dart';
import '../repositories/view_repository.dart';

/// The demo suite (debug menu / store screenshots): **wipes all content** and
/// seeds a realistic, feature-covering dataset — three Views, four Lenses
/// with real dials (one lens shared across two Views with different status
/// filters, a periodic chip-away lens, a capped backlog), six habits with
/// fabricated history (streak, mixed record, an avoidance case, a 2–3×-a-week
/// counter) and six
/// to-dos (dated with reminders + backlog). Names come from l10n, so the
/// suite doubles as screenshot content in all four languages.
///
/// App settings (theme, language, debug flag) survive — only content goes.
Future<void> loadDemoData(
  AppDatabase db,
  DateTime now,
  AppLocalizations l10n,
) async {
  final today = DateTime(now.year, now.month, now.day);
  DateTime day(int daysAgo) =>
      DateTime(today.year, today.month, today.day - daysAgo);
  // The most recent Monday at/before today (weekly anchors).
  final monday = day(today.weekday - DateTime.monday);
  // The most recent Saturday strictly before today.
  final lastSaturday = day(
    ((today.weekday - DateTime.saturday) + 7) % 7 == 0
        ? 7
        : ((today.weekday - DateTime.saturday) + 7) % 7,
  );

  await db.transaction(() async {
    await wipeContent(db);

    // --- views ---------------------------------------------------------------
    Future<int> view(String name, String icon, int sort) => db
        .into(db.views)
        .insert(
          ViewsCompanion.insert(
            name: name,
            icon: Value(icon),
            sortIndex: Value(sort),
          ),
        );
    final homeView = await view(l10n.demoViewHome, 'home', 0);
    final habitsView = await view(l10n.demoViewHabits, 'repeat', 1);
    final longtermView = await view(l10n.demoViewLongterm, 'inbox', 2);

    // --- lenses ----------------------------------------------------------------
    final dailyLens = await db
        .into(db.lenses)
        .insert(
          LensesCompanion.insert(
            name: l10n.demoLensDaily,
            ordering: LensOrdering.automatic,
            selection: LensSelection.top,
            sortIndex: const Value(0),
          ),
        );
    // The Habits view's tracker: the same daily habits, with outcomes shown.
    final dailyOutcomesLens = await db
        .into(db.lenses)
        .insert(
          LensesCompanion.insert(
            name: l10n.demoLensDailyOutcomes,
            ordering: LensOrdering.automatic,
            selection: LensSelection.top,
            sortIndex: const Value(4),
            statusFilter: const Value(5), // done(1) + missed(4)
          ),
        );
    final todosLens = await db
        .into(db.lenses)
        .insert(
          LensesCompanion.insert(
            name: l10n.demoLensTodos,
            ordering: LensOrdering.dueDate,
            selection: LensSelection.top,
            sortIndex: const Value(1),
            defaultKind: const Value(TaskKind.todo),
          ),
        );
    final weeklyLens = await db
        .into(db.lenses)
        .insert(
          LensesCompanion.insert(
            name: l10n.demoLensWeekly,
            ordering: LensOrdering.automatic,
            selection: LensSelection.top,
            showCount: const Value(1),
            period: Value(Recurrence.weekly(monday, on: {Weekday.mon})),
            sortIndex: const Value(2),
          ),
        );
    final backlogLens = await db
        .into(db.lenses)
        .insert(
          LensesCompanion.insert(
            name: l10n.demoLensBacklog,
            ordering: LensOrdering.automatic,
            selection: LensSelection.top,
            showCount: const Value(3),
            sortIndex: const Value(3),
          ),
        );

    // --- view ↔ lens ------------------------------------------------------------
    Future<void> link(int v, int l, int sort) => db
        .into(db.viewLens)
        .insert(
          ViewLensCompanion.insert(
            viewId: v,
            lensId: l,
            sortOrder: Value(sort),
          ),
        );
    await link(homeView, dailyLens, 0);
    await link(homeView, todosLens, 1);
    await link(habitsView, dailyOutcomesLens, 0);
    await link(habitsView, weeklyLens, 1);
    await link(longtermView, backlogLens, 0);

    // --- templates (habits) ---------------------------------------------------
    final repo = TaskRepository(db);

    Future<int> habit(
      String name,
      Recurrence recurrence,
      WindowRule rule,
      Set<int> lensIds, {
      List<TaskNotification> notifications = const [],
    }) => repo.createTemplate(
      Template(
        name: name,
        recurrence: recurrence,
        windowRule: rule,
        createdAt: now,
        notifications: notifications,
      ),
      lensIds: lensIds,
    );

    final brush = await habit(
      l10n.demoBrushTeeth,
      Recurrence.daily(day(6)),
      Slice.evening,
      {dailyLens, dailyOutcomesLens},
      notifications: const [TaskNotification.atStart()],
    );
    final stretch = await habit(
      l10n.demoStretch,
      Recurrence.daily(day(4)),
      Slice.morning,
      {dailyLens, dailyOutcomesLens},
    );
    // Anytime window: the avoidance amber is visible the whole demo day.
    final journal = await habit(
      l10n.demoJournal,
      Recurrence.daily(day(3)),
      const UntilNextOccurrence(),
      {dailyLens, dailyOutcomesLens},
    );
    final plants = await habit(
      l10n.demoWaterPlants,
      Recurrence.weekly(lastSaturday, on: {Weekday.sat}),
      const UntilNextOccurrence(),
      {dailyLens, dailyOutcomesLens},
    );
    final vacuum = await habit(
      l10n.demoVacuum,
      Recurrence.weekly(day(7), on: {Weekday.mon}),
      const UntilNextOccurrence(),
      {weeklyLens},
    );
    // A counter (§3.7): gym 2–3× a week, never twice a day.
    const gymGoal = Goal(min: 2, max: 3, oncePerDay: true);
    final firstGymWeek = DateTime(monday.year, monday.month, monday.day - 21);
    final gym = await repo.createTemplate(
      Template(
        name: l10n.demoGym,
        recurrence: Recurrence.weekly(firstGymWeek, on: {Weekday.mon}),
        createdAt: firstGymWeek,
        goal: gymGoal,
      ),
      lensIds: {dailyLens, dailyOutcomesLens},
    );

    // --- fabricated history (drives streaks, breakdowns, avoidance) ----------
    Future<void> instance(
      int templateId,
      String name,
      DateTime occ,
      DateTime start,
      DateTime end,
      TaskStatus status,
      DateTime? resolvedAt,
      Set<int> lensIds, {
      Goal goal = Goal.single,
      List<DateTime> checkIns = const [],
    }) => repo.createTask(
      Task(
        templateId: templateId,
        name: name,
        occurrence: occ,
        start: start,
        end: end,
        status: status,
        createdAt: occ,
        resolvedAt: resolvedAt,
        goal: goal,
        checkIns: checkIns,
      ),
      lensIds: lensIds,
    );

    DateTime at(DateTime d, int hour) => DateTime(d.year, d.month, d.day, hour);
    DateTime nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);

    // Brush teeth: a clean 6-day streak (Done d-6 … d-1).
    for (var i = 6; i >= 1; i--) {
      final d = day(i);
      await instance(
        brush,
        l10n.demoBrushTeeth,
        d,
        at(d, 18),
        nextDay(d),
        TaskStatus.done,
        at(d, 21),
        {dailyLens, dailyOutcomesLens},
      );
    }
    // Stretch (morning slice): mixed record ending done — including TODAY,
    // which at a typical afternoon demo time would otherwise auto-Miss.
    final stretchStatuses = [
      TaskStatus.done, // d-4
      TaskStatus.missed, // d-3
      TaskStatus.done, // d-2
      TaskStatus.done, // d-1
      TaskStatus.done, // today, done this morning
    ];
    for (var i = 0; i < stretchStatuses.length; i++) {
      final d = day(4 - i);
      final s = stretchStatuses[i];
      await instance(
        stretch,
        l10n.demoStretch,
        d,
        d,
        at(d, 12),
        s,
        s == TaskStatus.done ? at(d, 8) : at(d, 12),
        {dailyLens, dailyOutcomesLens},
      );
    }
    // Journal: three consecutive Misses → today renders in avoidance amber.
    for (var i = 3; i >= 1; i--) {
      final d = day(i);
      await instance(
        journal,
        l10n.demoJournal,
        d,
        d,
        nextDay(d),
        TaskStatus.missed,
        nextDay(d),
        {dailyLens, dailyOutcomesLens},
      );
    }
    // Water plants: last Saturday done; this week's back-fills open.
    await instance(
      plants,
      l10n.demoWaterPlants,
      lastSaturday,
      lastSaturday,
      DateTime(lastSaturday.year, lastSaturday.month, lastSaturday.day + 7),
      TaskStatus.done,
      at(lastSaturday, 10),
      {dailyLens, dailyOutcomesLens},
    );
    // Vacuum: last week done; this week's instance is the chip-away item.
    await instance(
      vacuum,
      l10n.demoVacuum,
      day(7),
      day(7),
      monday,
      TaskStatus.done,
      at(day(5), 16),
      {weeklyLens},
    );

    // Gym: three weeks back — 1 of 2 (missed), 3 of 3, 2 of 2–3 — so the
    // streak reads "2 weeks in a row"; this week, one check-in Monday
    // morning when the demo runs later that day (else none yet).
    DateTime weekOf(int weeksAgo) =>
        DateTime(monday.year, monday.month, monday.day - 7 * weeksAgo);
    DateTime nextWeek(DateTime week) =>
        DateTime(week.year, week.month, week.day + 7);
    DateTime on(DateTime week, int weekday, int hour) =>
        DateTime(week.year, week.month, week.day + weekday - 1, hour);
    final gymWeeks = [
      (weekOf(3), TaskStatus.missed, [1]), // Tue only
      (weekOf(2), TaskStatus.done, [2, 4, 6]), // Tue, Thu, Sat: capped
      (weekOf(1), TaskStatus.done, [3, 5]), // Wed, Fri: met at week end
    ];
    for (final (week, status, days) in gymWeeks) {
      final ins = [for (final d in days) on(week, d, 18)];
      final end = nextWeek(week);
      await instance(
        gym,
        l10n.demoGym,
        week,
        week,
        end,
        status,
        status == TaskStatus.missed ? end : ins.last,
        {dailyLens, dailyOutcomesLens},
        goal: gymGoal,
        checkIns: ins,
      );
    }
    final thisWeekIn = on(monday, 1, 7);
    await instance(
      gym,
      l10n.demoGym,
      monday,
      monday,
      nextWeek(monday),
      TaskStatus.open,
      null,
      {dailyLens, dailyOutcomesLens},
      goal: gymGoal,
      checkIns: thisWeekIn.isBefore(now) ? [thisWeekIn] : const [],
    );

    // --- one-offs -------------------------------------------------------------
    Future<void> todo(
      String name,
      int lensId, {
      DateTime? start,
      DateTime? end,
      List<TaskNotification> notifications = const [],
    }) => repo.createTask(
      Task(
        name: name,
        start: start,
        end: end,
        createdAt: now,
        notifications: notifications,
      ),
      lensId: lensId,
    );

    await todo(l10n.demoCallDentist, todosLens, end: at(today, 17));
    await todo(
      l10n.demoTrainTickets,
      todosLens,
      end: at(day(-1), 18),
      notifications: const [
        TaskNotification.atEnd(offset: Duration(hours: -2)),
      ],
    );
    await todo(l10n.demoLibraryBooks, todosLens, end: at(day(-2), 18));
    await todo(l10n.demoBikeLight, backlogLens);
    await todo(l10n.demoBirthday, backlogLens);
    await todo(l10n.demoPostcard, backlogLens);
  });

  // Generate today's open instances + stamp surfacing outside the seed
  // transaction (both are idempotent).
  await TaskRepository(db).reconcileAll(now);
  await ViewRepository(db).refreshSurfaced(now);
}

/// Wipe every content table (children → parents); `app_settings` stays.
/// Call inside a transaction. Shared by the demo loader and "Reset to intro".
Future<void> wipeContent(AppDatabase db) async {
  await db.delete(db.taskLens).go();
  await db.delete(db.viewLens).go();
  await db.delete(db.templateLens).go();
  await db.delete(db.tasks).go();
  await db.delete(db.templates).go();
  await db.delete(db.lenses).go();
  await db.delete(db.views).go();
  await db.delete(db.vacations).go();
}
