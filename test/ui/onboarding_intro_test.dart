import 'package:checkfuchs/l10n/app_localizations.dart';
import 'package:checkfuchs/ui/onboarding_intro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showOnboardingIntro(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  testWidgets('walks Task → Lens → View and finishes on the last button', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('A task is anything you do.'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('A lens picks a slice of your tasks.'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('A view arranges lenses into a screen.'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    await tester.tap(find.text('Set up my first habit'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingIntroScreen), findsNothing);
  });

  testWidgets('Skip leaves from any page', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingIntroScreen), findsNothing);
  });
}
