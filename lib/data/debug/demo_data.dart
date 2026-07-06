import 'package:drift/drift.dart';

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
/// filters, a periodic chip-away lens, a capped backlog), five habits with
/// fabricated history (streak, mixed record, an avoidance case) and six
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
    // --- wipe content (children → parents; appSettings stays) --------------
    await db.delete(db.taskLens).go();
    await db.delete(db.viewLens).go();
    await db.delete(db.tasks).go();
    await db.delete(db.templates).go();
    await db.delete(db.lenses).go();
    await db.delete(db.views).go();
    await db.delete(db.vacations).go();

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
    final homeView = await view('Home', 'home', 0);
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
    final todosLens = await db
        .into(db.lenses)
        .insert(
          LensesCompanion.insert(
            name: l10n.demoLensTodos,
            ordering: LensOrdering.dueDate,
            selection: LensSelection.top,
            sortIndex: const Value(1),
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

    // --- view ↔ lens (the same Daily lens reads differently per View) --------
    Future<void> link(int v, int l, int sort, [int filter = 0]) => db
        .into(db.viewLens)
        .insert(
          ViewLensCompanion.insert(
            viewId: v,
            lensId: l,
            sortOrder: Value(sort),
            statusFilter: Value(filter),
          ),
        );
    await link(homeView, dailyLens, 0);
    await link(homeView, todosLens, 1);
    await link(habitsView, dailyLens, 0, 5); // + done(1) + missed(4): tracker
    await link(habitsView, weeklyLens, 1);
    await link(longtermView, backlogLens, 0);

    // --- templates (habits) ---------------------------------------------------
    final repo = TaskRepository(db);

    Future<int> habit(
      String name,
      Recurrence recurrence,
      WindowRule rule,
      int lensId, {
      List<TaskNotification> notifications = const [],
    }) => repo.createTemplate(
      Template(
        name: name,
        recurrence: recurrence,
        windowRule: rule,
        createdAt: now,
        notifications: notifications,
      ),
      defaultLensId: lensId,
    );

    final brush = await habit(
      l10n.demoBrushTeeth,
      Recurrence.daily(day(6)),
      Slice.evening,
      dailyLens,
      notifications: const [TaskNotification.atStart()],
    );
    final stretch = await habit(
      l10n.demoStretch,
      Recurrence.daily(day(4)),
      Slice.morning,
      dailyLens,
    );
    // Anytime window: the avoidance amber is visible the whole demo day.
    final journal = await habit(
      l10n.demoJournal,
      Recurrence.daily(day(3)),
      const UntilNextOccurrence(),
      dailyLens,
    );
    final plants = await habit(
      l10n.demoWaterPlants,
      Recurrence.weekly(lastSaturday, on: {Weekday.sat}),
      const UntilNextOccurrence(),
      dailyLens,
    );
    final vacuum = await habit(
      l10n.demoVacuum,
      Recurrence.weekly(day(7), on: {Weekday.mon}),
      const UntilNextOccurrence(),
      weeklyLens,
    );

    // --- fabricated history (drives streaks, breakdowns, avoidance) ----------
    Future<void> instance(
      int templateId,
      String name,
      DateTime occ,
      DateTime start,
      DateTime end,
      TaskStatus status,
      DateTime resolvedAt,
      int lensId,
    ) => repo.createTask(
      Task(
        templateId: templateId,
        name: name,
        occurrence: occ,
        start: start,
        end: end,
        status: status,
        createdAt: occ,
        resolvedAt: resolvedAt,
      ),
      lensId: lensId,
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
        dailyLens,
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
        dailyLens,
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
        dailyLens,
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
      dailyLens,
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
      weeklyLens,
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
