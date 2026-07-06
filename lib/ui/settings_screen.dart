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
      // The knabberfuchs settings anatomy: uppercase section headers + white
      // cards grouping the rows, hairline dividers between rows.
      body: ListView(
        children: [
          SectionHeader(l10n.appearanceSection),
          SettingsCard(
            children: [
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
            ],
          ),
          SectionHeader(l10n.vacation),
          SettingsCard(
            children: [
              ListTile(
                contentPadding: cardRowPadding,
                leading: const Icon(Icons.beach_access_outlined),
                title: Text(l10n.vacation),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VacationScreen()),
                ),
              ),
            ],
          ),
          SectionHeader(l10n.remindersSection),
          SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text(
                  l10n.reminderDisclosure,
                  style: TextStyle(color: scheme.outline),
                ),
              ),
            ],
          ),
          SectionHeader(l10n.aboutSection),
          const SettingsCard(children: [_AboutTile()]),
          // Hidden developer section — unlocked via the About easter egg.
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
      contentPadding: cardRowPadding,
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

/// Row inset inside a [SettingsCard] (knabberfuchs `_cardRowPadding`).
const cardRowPadding = EdgeInsets.symmetric(horizontal: 12);

/// Groups a section's rows inside a single [Card], inserting a hairline
/// divider between consecutive rows. Card fill/border/radius come from the
/// theme — do not override them here. (Shared with [DebugSection].)
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Divider(height: 1, indent: 16, endIndent: 16));
      }
      rows.add(children[i]);
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(children: rows),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Semantics(
        header: true,
        child: Text(
          title.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.w700,
            letterSpacing: .6,
          ),
        ),
      ),
    );
  }
}
