import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'notifications/background_refresh.dart';
import 'providers.dart';
import 'ui/home_shell.dart';

void main() {
  runApp(const ProviderScope(child: CheckfuchsApp()));
  // After runApp, unawaited: the ~12h WorkManager refresh pass (Phase 5) must
  // never delay or break startup. Android-only inside; no-op elsewhere.
  try {
    unawaited(registerBackgroundRefresh());
  } catch (e) {
    debugPrint('registerBackgroundRefresh threw synchronously: $e');
  }
}

class CheckfuchsApp extends ConsumerWidget {
  const CheckfuchsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: CheckfuchsTheme.light(font: settings.font),
      darkTheme: CheckfuchsTheme.dark(font: settings.font),
      themeMode: settings.themeMode,
      locale: settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const HomeShell(),
    );
  }
}
