import 'package:checkfuchs/data/db/database.dart';
import 'package:checkfuchs/domain/recurrence.dart';
import 'package:checkfuchs/domain/template.dart';
import 'package:checkfuchs/domain/window_rule.dart';
import 'package:checkfuchs/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day, [int h = 0]) => DateTime(y, m, day, h);

void main() {
  test(
    'tasksProvider streams the reconciled tasks (in-memory override)',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final repo = container.read(taskRepositoryProvider);
      await repo.createTemplate(
        Template(
          name: 'Brush teeth',
          recurrence: Recurrence.daily(d(2026, 6, 27)),
          windowRule: Slice.morning,
          createdAt: d(2026, 6, 27),
        ),
      );
      await repo.reconcileAll(d(2026, 6, 27, 8));

      // The graph wires the in-memory db override → repository → reactive stream.
      final tasks = await container
          .read(taskRepositoryProvider)
          .watchTasks()
          .first;
      expect(tasks, hasLength(1));
      expect(tasks.single.name, 'Brush teeth');

      // And tasksProvider exposes that same stream to the UI.
      final sub = container.listen(tasksProvider, (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(tasksProvider).value, hasLength(1));
    },
  );

  test('onboardingDone round-trips through the settings controller', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    expect(container.read(settingsProvider).onboardingDone, isFalse);
    await container.read(settingsProvider.notifier).markOnboardingDone();
    expect(container.read(settingsProvider).onboardingDone, isTrue);

    // Persisted: the row carries the flag …
    final row = await db.select(db.appSettings).getSingle();
    expect(row.onboardingDone, isTrue);

    // … and a fresh controller over the same database loads it back.
    final container2 = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container2.dispose);
    final sub = container2.listen(settingsProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    expect(container2.read(settingsProvider).onboardingDone, isTrue);
  });
}
