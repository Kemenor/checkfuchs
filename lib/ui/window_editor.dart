import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../domain/window_rule.dart';
import '../l10n/app_localizations.dart';
import 'window_choice.dart';

/// The ACTIVE WINDOW section (examples/ui/07): multi-select preset chips,
/// "Custom…" adds a band row (from → to, ×), and a summary line spelling out
/// the merged bands and the "done once in any of them" rule.
class WindowEditor extends StatelessWidget {
  const WindowEditor({super.key, required this.value, required this.onChanged});

  final WindowSelection value;
  final ValueChanged<WindowSelection> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final w in WindowChoice.values)
              FilterChip(
                label: Text(w.label(l10n)),
                selected: w == WindowChoice.anytime
                    ? value.isAnytime
                    : value.presets.contains(w),
                onSelected: (_) => onChanged(value.toggle(w)),
              ),
            ActionChip(
              avatar: const Icon(Symbols.add_rounded, size: 18),
              label: Text(l10n.windowCustom),
              onPressed: () => onChanged(
                value.addCustom(
                  Band(
                    from: const Duration(hours: 13),
                    to: const Duration(hours: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
        for (var i = 0; i < value.custom.length; i++)
          _BandRow(
            key: ValueKey('band-$i'),
            band: value.custom[i],
            onChanged: (b) => onChanged(value.replaceCustom(i, b)),
            onRemove: () => onChanged(value.removeCustom(i)),
          ),
        if (!value.isAnytime)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Symbols.schedule_rounded,
                  size: 16,
                  color: scheme.secondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value.hasGaps
                        ? l10n.windowBandsSummaryMulti(value.describe(context))
                        : l10n.windowBandsSummary(value.describe(context)),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: scheme.outline),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BandRow extends StatelessWidget {
  const _BandRow({
    super.key,
    required this.band,
    required this.onChanged,
    required this.onRemove,
  });

  final Band band;
  final ValueChanged<Band> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    TimeOfDay tod(Duration d) =>
        TimeOfDay(hour: d.inHours % 24, minute: d.inMinutes % 60);
    Duration dur(TimeOfDay t) => Duration(hours: t.hour, minutes: t.minute);

    Future<void> pick(bool from) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: tod(from ? band.from : band.to),
      );
      if (picked == null) return;
      var d = dur(picked);
      if (from) {
        if (d >= band.to) d = band.to - const Duration(minutes: 15);
        if (d.isNegative) return;
        onChanged(Band(from: d, to: band.to));
      } else {
        if (d == Duration.zero) d = const Duration(hours: 24); // midnight = end
        if (d <= band.from) d = band.from + const Duration(minutes: 15);
        onChanged(Band(from: band.from, to: d));
      }
    }

    String label(Duration d) =>
        d == const Duration(hours: 24) ? '24:00' : loc.formatTimeOfDay(tod(d));

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.secondary),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: () => pick(true),
            child: Text(label(band.from)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Symbols.arrow_forward_rounded,
              size: 18,
              color: scheme.outline,
            ),
          ),
          OutlinedButton(
            onPressed: () => pick(false),
            child: Text(label(band.to)),
          ),
          const Spacer(),
          IconButton(
            tooltip: loc.deleteButtonTooltip,
            icon: const Icon(Symbols.close_rounded),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
