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

/// A walk through every flow, for review (not for the store — that's
/// `screenshots_test.dart`, which keeps Google Play's 8-shot set):
///
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/flows_test.dart -d `<device>`
///
/// Shots land in `screenshots/flows/NN_name.png`. Starts on an empty
/// database so the onboarding pager is real, then seeds the demo suite and
/// visits each screen and sheet. Every step is guarded: a tap that finds
/// nothing skips its shot instead of failing the run.
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

  testWidgets('flow screenshots', (tester) async {
    await initializeDateFormatting();
    final l10n = lookupAppLocalizations(const Locale(loc));

    final container = ProviderContainer();
    final db = container.read(databaseProvider);
    // Language pinned, Stats tab on — but onboarding NOT stamped, so the
    // intro pager runs and can be captured.
    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion(
            id: const Value(1),
            onboardingDone: const Value(false),
            localeCode: const Value(loc),
            statsTab: const Value(true),
          ),
        );

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

    var n = 0;
    Future<void> shot(String name) async {
      await settle(tester);
      n++;
      final idx = n.toString().padLeft(2, '0');
      await binding.takeScreenshot('flows/${idx}_$name');
    }

    Element homeCtx() =>
        tester.element(find.byType(HomeShell, skipOffstage: false).first);

    Future<void> popToHome() async {
      Navigator.of(homeCtx()).popUntil((r) => r.isFirst);
      await settle(tester);
    }

    Future<void> back() async {
      final nav = Navigator.of(tester.element(find.byType(Scaffold).last));
      if (nav.canPop()) nav.pop();
      await settle(tester);
    }

    Future<bool> tapText(String text, {bool last = false}) async {
      final f = find.text(text);
      if (f.evaluate().isEmpty) return false;
      final target = last ? f.last : f.first;
      try {
        await tester.ensureVisible(target);
        await settle(tester);
        await tester.tap(target);
      } catch (_) {
        return false;
      }
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

    Future<void> tab(String label) async {
      await popToHome();
      await tapText(label, last: true);
    }

    /// Run a flow; a missing widget skips it instead of killing the walk.
    Future<void> flow(String label, Future<void> Function() body) async {
      try {
        await body();
      } catch (e) {
        debugPrint('flow "$label" skipped: $e');
      }
      await popToHome();
    }

    // ---------------------------------------------------------------- intro
    await flow('intro', () async {
      await shot('intro_task');
      if (await tapText(l10n.introNext)) await shot('intro_lens');
      if (await tapText(l10n.introNext)) await shot('intro_view');
      // "Start clean" hands over to the Add sheet, preset to a daily habit.
      if (await tapText(l10n.introStartClean)) await shot('first_task');
    });

    // The rest of the walk uses the demo suite.
    await db
        .into(db.appSettings)
        .insertOnConflictUpdate(
          const AppSettingsCompanion(
            id: Value(1),
            onboardingDone: Value(true),
          ),
        );
    await loadDemoData(db, DateTime.now(), l10n);
    await settle(tester);

    // ----------------------------------------------------------- the views
    await flow('views', () async {
      await tab(l10n.demoViewHome);
      await shot('home');
      await tab(l10n.demoViewHabits);
      await shot('view_habits');
      await tab(l10n.demoViewLongterm);
      await shot('view_longterm');
    });

    // --------------------------------------------------------- create flows
    await flow('create habit', () async {
      await tab(l10n.demoViewHome);
      if (!await tapText(l10n.addTask)) return;
      await shot('create_habit');
      final field = find.byType(TextField);
      if (field.evaluate().isNotEmpty) {
        await tester.enterText(field.first, l10n.demoWaterPlants);
        FocusManager.instance.primaryFocus?.unfocus();
        await settle(tester);
      }
      // Window: two bands over a two-day span.
      await tapText(l10n.windowDays(2));
      await tapText(l10n.windowMorning);
      await tapText(l10n.windowEvening);
      await shot('create_habit_window');
      // Reminders: a preset plus a custom day-anchored row.
      await tapText(l10n.remindWhenOpens);
      await tapText(l10n.remindAtTime);
      await shot('create_habit_reminders');
    });

    await flow('create to-do', () async {
      await tab(l10n.demoViewHome);
      if (!await tapText(l10n.addTask)) return;
      if (await tapText(l10n.kindTodo)) await shot('create_todo');
      // An undated to-do offers a fixed date+time reminder instead.
      await tapText(l10n.remindAtTime);
      await shot('create_todo_reminder');
    });

    // ------------------------------------------------------- habit detail
    await flow('habit detail', () async {
      await tab(l10n.demoViewHome);
      if (!await tapText(l10n.demoBrushTeeth)) return;
      await shot('detail_habit');
      if (await tapText(l10n.activeWindowSection)) {
        await shot('detail_window');
        await back();
      }
      if (await tapText(l10n.repeatSection)) {
        await shot('detail_repeat');
        await back();
      }
      if (await tapText(l10n.lensSection)) {
        await shot('detail_lenses');
        await tapText(l10n.cancel);
      }
      if (await tapText(l10n.historyTitle)) await shot('history');
    });

    await flow('to-do detail', () async {
      await tab(l10n.demoViewLongterm);
      if (await tapText(l10n.demoBikeLight)) await shot('detail_todo');
    });

    // -------------------------------------------------------------- stats
    await flow('stats', () async {
      await tab(l10n.statsTitle);
      await shot('stats');
      final edit = find.byTooltip(l10n.statsEditTiles);
      if (edit.evaluate().isNotEmpty) {
        await tester.tap(edit.first);
        await shot('stats_tiles');
      }
    });

    // ----------------------------------------------------------- settings
    await flow('settings', () async {
      await tab(l10n.settings);
      await shot('settings');
      if (await tapRow(l10n.allTasksTitle)) await shot('all_tasks');
    });

    await flow('lenses', () async {
      await tab(l10n.settings);
      if (!await tapRow(l10n.allLensesTitle)) return;
      await shot('all_lenses');
      if (await tapText(l10n.demoLensDaily)) await shot('lens_edit');
    });

    await flow('views library', () async {
      await tab(l10n.settings);
      if (!await tapRow(l10n.allViewsTitle)) return;
      await shot('all_views');
      if (!await tapText(l10n.demoViewHome)) return;
      await shot('view_edit');
      if (await tapText(l10n.demoLensDaily)) await shot('view_lens_edit');
    });

    await flow('vacation', () async {
      await tab(l10n.settings);
      if (await tapRow(l10n.vacation)) await shot('vacation');
    });

    // --------------------------------------------------- structure + dark
    await flow('structure sheet', () async {
      await tab(l10n.demoViewHome);
      final fab = find.byTooltip(l10n.structureTooltip);
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab.first);
        await shot('structure_sheet');
      }
    });

    await flow('dark theme', () async {
      await container
          .read(settingsProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      await settle(tester);
      await tab(l10n.demoViewHome);
      await shot('home_dark');
      if (await tapText(l10n.demoBrushTeeth)) await shot('detail_habit_dark');
      await popToHome();
      await container
          .read(settingsProvider.notifier)
          .setThemeMode(ThemeMode.system);
    });
  });
}
