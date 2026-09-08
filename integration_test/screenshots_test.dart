import 'dart:io';

import 'package:checkfuchs/data/db/database.dart';
import 'package:checkfuchs/data/debug/demo_data.dart';
import 'package:checkfuchs/l10n/app_localizations.dart';
import 'package:checkfuchs/main.dart';
import 'package:checkfuchs/providers.dart';
import 'package:checkfuchs/ui/home_shell.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Store screenshots, one locale per run (the single source of the shot
/// list — `tool/screenshots.sh` drives it and files the PNGs):
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshots_test.dart \
///     --dart-define=LOCALE=de -d `<device>`
///
/// Screenshots land in `screenshots/<locale>/NN_name.png`. The app is put
/// into the locale via its own language override, onboarding is pre-stamped,
/// and the demo suite (already localized) is seeded — so every locale's set
/// looks native and nothing but the app's own UI is on screen.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const loc = String.fromEnvironment('LOCALE', defaultValue: 'en');

  Future<void> settle(WidgetTester t) async {
    try {
      await t.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 8),
      );
    } catch (_) {
      await t.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets('store screenshots', (tester) async {
    await initializeDateFormatting();
    final l10n = lookupAppLocalizations(Locale(loc));

    final container = ProviderContainer();
    final db = container.read(databaseProvider);
    // Marketing state before the first frame: language pinned, onboarding
    // already offered, Stats tab on, and the demo suite seeded.
    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion(
            id: const Value(1),
            onboardingDone: const Value(true),
            localeCode: Value(loc),
            statsTab: const Value(true),
          ),
        );
    await loadDemoData(db, DateTime.now(), l10n);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CheckfuchsApp(),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.byType(HomeShell).evaluate().isNotEmpty) break;
    }
    await settle(tester);
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();

    Element homeCtx() =>
        tester.element(find.byType(HomeShell, skipOffstage: false).first);

    Future<void> shot(String name) async {
      await settle(tester);
      await binding.takeScreenshot('$loc/$name');
    }

    Future<void> popToHome() async {
      Navigator.of(homeCtx()).popUntil((r) => r.isFirst);
      await settle(tester);
    }

    Future<bool> tapText(String text, {bool last = false}) async {
      final f = find.text(text);
      if (f.evaluate().isEmpty) return false;
      final target = last ? f.last : f.first;
      await tester.ensureVisible(target);
      await settle(tester);
      await tester.tap(target);
      await settle(tester);
      return true;
    }

    Future<bool> tapRow(String text) async {
      try {
        await tester.scrollUntilVisible(
          find.text(text),
          250,
          scrollable: find.byType(Scrollable).first,
          maxScrolls: 40,
        );
      } catch (_) {}
      return tapText(text);
    }

    // Bottom-bar tabs are labelled with the view names (the demo seeds
    // 'Home' untranslated, the others localized) plus Stats and Settings.
    Future<void> tab(String label) async {
      await popToHome();
      await tapText(label, last: true);
    }

    // The marketing set: 8 scenes (Google Play's cap). Each starts from the
    // bare shell so a leftover route can't bleed into the next shot.

    // 1. Home — daily habits + to-dos, the calm glance.
    await tab('Home');
    await shot('01_home');

    // 2. Habits — the tracker view with a periodic lens.
    await tab(l10n.demoViewHabits);
    await shot('02_habits');

    // 3. Task detail — streak, reminders, lens, repeat.
    try {
      await tab('Home');
      if (await tapText(l10n.demoJournal)) await shot('03_detail');
    } catch (_) {}

    // 4. New task — multi-band window + reminders.
    try {
      await tab('Home');
      if (await tapText(l10n.addTask)) {
        final field = find.byType(TextField);
        if (field.evaluate().isNotEmpty) {
          await tester.enterText(field.first, l10n.demoWaterPlants);
          await settle(tester);
        }
        await tapText(l10n.windowMorning);
        await tapText(l10n.windowEvening);
        await tapText(l10n.remindWhenOpens);
        FocusManager.instance.primaryFocus?.unfocus();
        await settle(tester);
        await shot('04_create');
      }
    } catch (_) {}

    // 5. Stats — the tile digest.
    await tab(l10n.statsTitle);
    await shot('05_stats');

    // 6. Edit this view — the lens dials.
    try {
      await tab(l10n.settings);
      if (await tapRow(l10n.allViewsTitle) && await tapText('Home')) {
        await shot('06_edit_view');
      }
    } catch (_) {}

    // 7. Long-term — the backlog.
    await tab(l10n.demoViewLongterm);
    await shot('07_longterm');

    // 8. Home in the dark theme.
    await popToHome();
    await container
        .read(settingsProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    await settle(tester);
    await tab('Home');
    await shot('08_home_dark');
    await container
        .read(settingsProvider.notifier)
        .setThemeMode(ThemeMode.system);
  });
}
