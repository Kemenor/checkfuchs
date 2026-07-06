import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuchsbau/fuchsbau.dart';

import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'debug_section.dart';
import 'vacation_screen.dart';

/// Settings (Phase 8): theme override, the Fuchsbau accessibility typeface
/// picker, and the honest reminder-lapse disclosure (§5 / no-dark-patterns).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // The shared collapsible pickers (knabberfuchs parity): current
          // choice as the collapsed subtitle, radio list when expanded. The
          // tiles are self-titled, so no section headers here.
          FuchsbauChoicePicker<ThemeMode>(
            icon: Icons.brightness_6_rounded,
            title: l10n.appearanceSection,
            value: settings.themeMode,
            options: {
              ThemeMode.system: l10n.themeSystem,
              ThemeMode.light: l10n.themeLight,
              ThemeMode.dark: l10n.themeDark,
            },
            onChanged: controller.setThemeMode,
          ),
          FuchsbauChoicePicker<FuchsbauFont>(
            icon: Icons.text_fields_rounded,
            title: l10n.typefaceSection,
            value: settings.font,
            options: {for (final f in FuchsbauFont.values) f: f.label},
            subtitles: {
              FuchsbauFont.figtree: l10n.typefaceDefault,
              FuchsbauFont.atkinsonHyperlegible: l10n.typefaceLowVision,
              FuchsbauFont.openDyslexic: l10n.typefaceDyslexia,
            },
            onChanged: controller.setFont,
          ),
          FuchsbauChoicePicker<String>(
            icon: Icons.translate_rounded,
            title: l10n.languageSection,
            value: settings.localeCode,
            options: {
              'system': l10n.languageSystem,
              'en': l10n.languageEnglish,
              'de': l10n.languageGerman,
              'fr': l10n.languageFrench,
              'it': l10n.languageItalian,
            },
            onChanged: controller.setLocaleCode,
          ),
          const SizedBox(height: 24),
          _Section(l10n.vacation),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.beach_access_outlined),
            title: Text(l10n.vacation),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const VacationScreen())),
          ),
          const SizedBox(height: 24),
          _Section(l10n.remindersSection),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.reminderDisclosure,
              style: TextStyle(color: scheme.outline),
            ),
          ),
          const SizedBox(height: 24),
          _Section(l10n.aboutSection),
          const _AboutTile(),
          if (settings.debugMenu) const DebugSection(),
        ],
      ),
    );
  }
}

/// About entry — shows the real app version+build and opens an about dialog
/// with a "view licenses" button. Hand-rolled instead of [showAboutDialog]
/// because the app name doubles as the debug-menu unlock: long-pressing it
/// toggles the hidden Debug section (the knabberfuchs easter egg).
class _AboutTile extends ConsumerWidget {
  const _AboutTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final version = ref.watch(appVersionProvider).asData?.value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.info_outline_rounded),
      title: const Text('Checkfuchs'),
      subtitle: version == null ? null : Text(version),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showDialog<void>(
        context: context,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          final material = MaterialLocalizations.of(ctx);
          return AlertDialog(
            title: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: () => _toggleDebugMenu(ctx, ref),
              child: Text('Checkfuchs 🦊', style: theme.textTheme.titleLarge),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (version != null)
                  Text(version, style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                Text(l10n.aboutBody),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => showLicensePage(
                  context: ctx,
                  applicationName: 'Checkfuchs',
                  applicationVersion: version,
                ),
                child: Text(material.viewLicensesButtonLabel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(material.closeButtonLabel),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Debug-menu easter egg: flips the setting and closes the dialog so the
  /// new Settings section is immediately visible. English-only by design.
  Future<void> _toggleDebugMenu(BuildContext dialogCtx, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(dialogCtx);
    final on = await ref.read(settingsProvider.notifier).toggleDebugMenu();
    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
    messenger.showSnackBar(
      SnackBar(content: Text(on ? 'Debug menu enabled' : 'Debug menu hidden')),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.outline,
          fontWeight: FontWeight.w700,
          letterSpacing: .6,
        ),
      ),
    );
  }
}
