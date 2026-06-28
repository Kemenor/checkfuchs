import 'package:checkfuchs/data/db/database.dart';
import 'package:checkfuchs/domain/clock.dart';
import 'package:checkfuchs/domain/task.dart';
import 'package:checkfuchs/main.dart';
import 'package:checkfuchs/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots to the empty home state when there are no tasks',
      (tester) async {
    // In-memory db only for the harmless reconcile-on-launch call; the task
    // stream is overridden with a plain stream so no drift *watch* (and its
    // cleanup Timer) lands in the widget tree.
    final db = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 6, 27, 8))),
        tasksProvider.overrideWith((ref) => Stream.value(const <Task>[])),
      ],
      child: const CheckfuchsApp(),
    ));

    for (var i = 0;
        i < 20 && find.text('Nothing here yet').evaluate().isEmpty;
        i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });
}
