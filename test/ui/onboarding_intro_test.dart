import 'package:checkfuchs/l10n/app_localizations.dart';
import 'package:checkfuchs/ui/onboarding_intro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  IntroChoice? result;
  var returned = false;
  Widget host() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              result = await showOnboardingIntro(context);
              returned = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  setUp(() {
    result = null;
    returned = false;
  });

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
    expect(find.text('Load example data'), findsOneWidget);
    await tester.tap(find.text('Start clean'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingIntroScreen), findsNothing);
    expect(returned, isTrue);
    expect(result, IntroChoice.clean);
  });

  testWidgets('the example-data button returns the demo choice', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load example data'));
    await tester.pumpAndSettle();
    expect(result, IntroChoice.demo);
  });

  testWidgets('Skip leaves from any page', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingIntroScreen), findsNothing);
    expect(returned, isTrue);
    expect(result, isNull);
  });
}
