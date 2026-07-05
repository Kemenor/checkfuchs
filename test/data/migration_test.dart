import 'package:checkfuchs/data/db/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke test only: a fresh in-memory database runs `onCreate` (createAll) and
/// `beforeOpen`. Verifying the real v1→v4 upgrade path would need exported
/// drift schema files (drift_dev's schema tooling) — out of scope here.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a fresh database opens at schemaVersion 4', () async {
    await db.select(db.tasks).get(); // force the lazy open
    expect(db.schemaVersion, 4);
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
}
