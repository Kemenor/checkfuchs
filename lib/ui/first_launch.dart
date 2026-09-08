import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/debug/demo_data.dart';
import '../domain/recurrence.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'onboarding_intro.dart';
import 'create_task_sheet.dart';

/// The first-launch flow: stamp "offered", run the intro pager, then either
/// the Add sheet preset to a daily habit — the carrier — (clean start /
/// skipped) or the example dataset.
/// Shared by the startup check and the developer "Reset to intro".
Future<void> runFirstLaunch(BuildContext context, WidgetRef ref) async {
  await ref.read(settingsProvider.notifier).markOnboardingDone();
  if (!context.mounted) return;
  final choice = await showOnboardingIntro(context);
  if (!context.mounted) return;
  switch (choice) {
    case IntroChoice.demo:
      await loadDemoData(
        ref.read(databaseProvider),
        ref.read(clockProvider).now(),
        AppLocalizations.of(context),
      );
    case IntroChoice.clean || null:
      final now = ref.read(clockProvider).now();
      await showCreateTaskSheet(
        context,
        ref,
        initialRecurrence: Recurrence.daily(
          DateTime(now.year, now.month, now.day),
        ),
      );
  }
}
