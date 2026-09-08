import 'package:checkfuchs/data/db/database.dart';
import 'package:checkfuchs/data/debug/demo_data.dart';
import 'package:checkfuchs/data/repositories/task_repository.dart';
import 'package:checkfuchs/domain/analytics.dart';
import 'package:checkfuchs/domain/task.dart';
import 'package:checkfuchs/l10n/app_localizations.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final l10n = lookupAppLocalizations(const Locale('en'));
  final now = DateTime(2026, 7, 6, 15); // a Monday afternoon

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('wipes existing content and seeds the full suite', () async {
    // Pre-existing junk that must vanish (settings must survive).
    final repo = TaskRepository(db);
    await repo.createTask(Task(name: 'junk', createdAt: now));
    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(
          const AppSettingsCompanion(id: Value(1), debugMenu: Value(true)),
        );

    await loadDemoData(db, now, l10n);

    final tasks = await repo.allTasks();
    expect(tasks.map((t) => t.name), isNot(contains('junk')));
    expect((await db.select(db.views).get()).length, 3);
    expect((await db.select(db.lenses).get()).length, 4);
    expect((await db.select(db.templates).get()).length, 5);
    // Settings survived the wipe.
    final settings = await db.select(db.appSettings).getSingle();
    expect(settings.debugMenu, isTrue);
  });

  test('every habit ends with exactly one open instance', () async {
    await loadDemoData(db, now, l10n);
    final repo = TaskRepository(db);
    for (final t in await db.select(db.templates).get()) {
      final open = (await repo.tasksForTemplate(
        t.id,
      )).where((x) => x.isOpen).length;
      expect(open, 1, reason: '${t.name} should have one open instance');
    }
  });

  test('history drives streaks and avoidance', () async {
    await loadDemoData(db, now, l10n);
    final repo = TaskRepository(db);
    final templates = await db.select(db.templates).get();

    final brush = templates.firstWhere((t) => t.name == l10n.demoBrushTeeth);
    final brushStats = computeStats(await repo.tasksForTemplate(brush.id));
    expect(brushStats.currentStreak, 6);

    final journal = templates.firstWhere((t) => t.name == l10n.demoJournal);
    final journalStats = computeStats(await repo.tasksForTemplate(journal.id));
    expect(journalStats.consecutiveMisses, 3);
    expect(journalStats.isAvoided, isTrue);

    final stretch = templates.firstWhere((t) => t.name == l10n.demoStretch);
    final stretchStats = computeStats(await repo.tasksForTemplate(stretch.id));
    expect(stretchStats.currentStreak, 3); // today + 2, then a miss behind
    expect(stretchStats.missed, 1);
  });

  test('is idempotent — loading twice leaves one clean suite', () async {
    await loadDemoData(db, now, l10n);
    await loadDemoData(db, now, l10n);
    expect((await db.select(db.views).get()).length, 3);
    expect((await db.select(db.templates).get()).length, 5);
  });
}
