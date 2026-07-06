import 'dart:io';

import 'package:checkfuchs/data/db/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke test only: a fresh in-memory database runs `onCreate` (createAll) and
/// `beforeOpen`. Verifying the real v1→v5 upgrade path would need exported
/// drift schema files (drift_dev's schema tooling) — out of scope here.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a fresh database opens at the current schemaVersion', () async {
    await db.select(db.tasks).get(); // force the lazy open
    expect(db.schemaVersion, 5);
  });

  test('PRAGMA foreign_keys is ON after open (beforeOpen ran)', () async {
    final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(row.data.values.single, 1);
  });

  test('createAll materialised every table', () async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final names = rows.map((r) => r.data['name']).toSet();
    expect(
      names,
      containsAll([
        'templates',
        'tasks',
        'lenses',
        'views',
        'task_lens',
        'view_lens',
        'vacations',
        'app_settings',
      ]),
    );
  });

  test('migration heals a half-migrated database (stale user_version over '
      'current-shape tables — the wedged-dogfood regression)', () async {
    // onUpgrade is NOT transactional: a crash mid-migration persists DDL
    // without bumping user_version. Worst case: every table already has its
    // current shape but user_version says 1, so all branches re-run.
    final dir = await Directory.systemTemp.createTemp('checkfuchs-mig');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/wedged.sqlite');

    final first = AppDatabase(NativeDatabase(file));
    await first.select(first.tasks).get(); // create everything, current shape
    await first.customStatement('PRAGMA user_version = 1');
    await first.close();

    final reopened = AppDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    // Must not throw (duplicate column / duplicate table), and end current.
    await reopened.select(reopened.tasks).get();
    final v = await reopened.customSelect('PRAGMA user_version').getSingle();
    expect(v.data.values.single, reopened.schemaVersion);
  });
}
