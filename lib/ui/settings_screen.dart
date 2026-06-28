import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuchsbau/fuchsbau.dart';

import '../providers.dart';

/// Settings (Phase 8): theme override, the Fuchsbau accessibility typeface
/// picker, and the honest reminder-lapse disclosure (§5 / no-dark-patterns).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Section('Appearance'),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) => controller.setThemeMode(s.first),
          ),
          const SizedBox(height: 24),
          const _Section('Typeface'),
          for (final font in FuchsbauFont.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(font.label,
                  style: TextStyle(fontFamily: font.family)),
              trailing: settings.font == font
                  ? Icon(Icons.check, color: scheme.primary)
                  : null,
              onTap: () => controller.setFont(font),
            ),
          const SizedBox(height: 24),
          const _Section('Reminders'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Reminders are scheduled locally on your device — no server, no '
              'account. If you don\'t open Checkfuchs for a long stretch, some '
              'reminders may stop firing until you come back.',
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
