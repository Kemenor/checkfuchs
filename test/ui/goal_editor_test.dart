import 'package:checkfuchs/domain/goal.dart';
import 'package:checkfuchs/l10n/app_localizations.dart';
import 'package:checkfuchs/ui/goal_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  late Goal goal;

  Widget host({int spanDays = 7}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: StatefulBuilder(
        builder: (context, setState) => GoalEditor(
          value: goal,
          unit: 'a week',
          spanDays: spanDays,
          onChanged: (g) => setState(() => goal = g),
        ),
      ),
    ),
  );

  setUp(() => goal = Goal.single);

  testWidgets('collapsed: one stepper, nothing else at 1 of 1', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('a week'), findsOneWidget);
    expect(find.text('Range…'), findsOneWidget);
    expect(find.text('Once a day'), findsNothing);
    expect(find.text('Remind until'), findsNothing);

    await tester.tap(find.byIcon(Symbols.add_rounded));
    await tester.pump();
    expect(goal, const Goal.times(2)); // fixed: at least = at most
    expect(find.text('Once a day'), findsOneWidget); // the week has room
    expect(find.text('Remind until'), findsNothing); // only for a range
  });

  testWidgets('Range… splits the stepper; No limit drops the cap', (
    tester,
  ) async {
    goal = const Goal.times(2);
    await tester.pumpWidget(host());
    await tester.tap(find.text('Range…'));
    await tester.pump();
    expect(find.text('At least'), findsOneWidget);
    expect(find.text('At most'), findsOneWidget);

    // Raise at most: 2 → 3.
    await tester.tap(find.byIcon(Symbols.add_rounded).last);
    await tester.pump();
    expect(goal, const Goal(min: 2, max: 3));
    expect(find.text('Remind until'), findsOneWidget);

    await tester.tap(find.text('No limit'));
    await tester.pump();
    expect(goal.max, isNull);

    // Folding the range back snaps at most to at least.
    await tester.tap(find.text('Range'));
    await tester.pump();
    expect(goal, const Goal.times(2));
  });

  testWidgets('a one-day window never offers once a day', (tester) async {
    goal = const Goal.times(2);
    await tester.pumpWidget(host(spanDays: 1));
    expect(find.text('Once a day'), findsNothing);
  });
}
