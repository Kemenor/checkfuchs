import 'package:checkfuchs/data/db/database.dart';
import 'package:checkfuchs/l10n/app_localizations.dart';
import 'package:checkfuchs/providers.dart';
import 'package:checkfuchs/ui/stats_tiles.dart';
import 'package:checkfuchs/ui/stats_tiles_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('orderedTiles: enabled first in stored order, then the rest', () {
    expect(orderedTiles(['streaks', 'completion', 'bogus']).map((t) => t.id), [
      'streaks',
      'completion',
      'week',
      'insight',
      'heatmap',
      'byWindow',
      'missesByWeekday',
    ]);
  });

  testWidgets('toggling a tile persists through the settings notifier', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StatsTilesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SwitchListTile), findsNWidgets(StatsTile.values.length));
    // Insight is off by default → switch it on.
    final insight = find.widgetWithText(SwitchListTile, 'Insight');
    expect(tester.widget<SwitchListTile>(insight).value, isFalse);
    await tester.tap(
      find.descendant(of: insight, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).effectiveStatsTiles, [
      'completion',
      'week',
      'streaks',
      'byWindow',
      'insight',
    ]);
    final row = await db.select(db.appSettings).getSingle();
    expect(row.statsTiles, contains('insight'));
  });
}
