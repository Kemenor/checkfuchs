import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuchsbau/fuchsbau.dart';

import '../l10n/app_localizations.dart';
import '../providers.dart';
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
          _Section(l10n.appearanceSection),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.themeSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.themeLight),
              ),
              ButtonSegment(value: ThemeMode.dark, label: Text(l10n.themeDark)),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) => controller.setThemeMode(s.first),
          ),
          const SizedBox(height: 24),
          _Section(l10n.typefaceSection),
          for (final font in FuchsbauFont.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                font.label,
                style: TextStyle(fontFamily: font.family),
              ),
              trailing: settings.font == font
                  ? Icon(Icons.check, color: scheme.primary)
                  : null,
              onTap: () => controller.setFont(font),
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
        ],
      ),
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
