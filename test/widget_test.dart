import 'package:checkfuchs/data/db/database.dart';
import 'package:checkfuchs/data/repositories/view_repository.dart';
import 'package:checkfuchs/domain/clock.dart';
import 'package:checkfuchs/main.dart';
import 'package:checkfuchs/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots to the empty home state when there are no tasks', (
    tester,
  ) async {
    // In-memory db for the harmless seed/reconcile-on-launch; the view streams
    // are overridden with plain streams so no drift *watch* (and its cleanup
    // Timer) lands in the widget tree.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    const home = ViewRow(id: 1, name: 'Home', sortIndex: 0);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FixedClock(DateTime(2026, 6, 27, 8))),
          viewsProvider.overrideWith((ref) => Stream.value(const [home])),
          viewStateProvider(1).overrideWith(
            (ref) => Stream.value(
              ViewState(
                view: home,
                sections: const [],
                nextTransition: DateTime(2026, 6, 28),
              ),
            ),
          ),
          // No notification runtime in tests — and the sync debounce Timer
          // would trip the pending-timers invariant at teardown.
          notificationSyncProvider.overrideWith((ref) {}),
        ],
        child: const CheckfuchsApp(),
      ),
    );

    for (
      var i = 0;
      i < 20 && find.text('Nothing here yet').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });
}
