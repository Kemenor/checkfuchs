import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../domain/window_rule.dart';
import '../l10n/app_localizations.dart';
import 'window_choice.dart';

/// The ACTIVE WINDOW section, two rows: *how long* (same day / N days /
/// until the next occurrence) and *which hours* (multi-select preset chips,
/// "Custom…" adds a band row) — the hours repeat on each day of the span.
/// A summary line spells out the merged result and the "done once in any of
/// them" rule.
class WindowEditor extends StatelessWidget {
  const WindowEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.recurring = false,
  });

  final WindowSelection value;
  final ValueChanged<WindowSelection> onChanged;

  /// For a series the span row is offered (one-offs pin their days with
  /// Starts/Due instead).
  final bool recurring;

  static const _quickDays = [1, 2, 3, 7];

  String _summary(BuildContext context, AppLocalizations l10n) {
    final days = value.days;
    final span = days == null
        ? l10n.windowUntilNextSummary
        : l10n.windowDaysSummary(days);
    if (value.allDay) return span;
    final hours = value.describe(context);
    if (days == 1) {
      return value.hasGaps
          ? l10n.windowBandsSummaryMulti(hours)
          : l10n.windowBandsSummary(hours);
    }
    final each = value.hasGaps
        ? l10n.windowBandsEachDayMulti(hours)
        : l10n.windowBandsEachDay(hours);
    return '$span $each';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: scheme.outline,
      fontWeight: FontWeight.w600,
    );
    final customDays = value.days != null && !_quickDays.contains(value.days);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (recurring) ...[
          Text(l10n.windowHowLong, style: labelStyle),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(l10n.windowUntilNext),
                selected: value.days == null,
                onSelected: (_) => onChanged(value.withDays(null)),
              ),
              ChoiceChip(
                label: Text(l10n.windowSameDay),
                selected: value.days == 1,
                onSelected: (_) => onChanged(value.withDays(1)),
              ),
              for (final n in _quickDays)
                if (n != 1)
                  ChoiceChip(
                    label: Text(l10n.windowDays(n)),
                    selected: value.days == n,
                    onSelected: (_) => onChanged(value.withDays(n)),
                  ),
              // Any other number of days: the chip shows the current custom
              // value once one is set.
              ChoiceChip(
                avatar: const Icon(Symbols.edit_rounded, size: 16),
                label: Text(
                  customDays ? l10n.windowDays(value.days!) : l10n.windowCustom,
                ),
                selected: customDays,
                onSelected: (_) async {
                  final n = await _askDays(context, value.days ?? 14);
                  if (n != null) onChanged(value.withDays(n));
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(l10n.windowWhichHours, style: labelStyle),
          const SizedBox(height: 6),
        ],
        Wrap(
          spacing: 8,
          children: [
            for (final w in WindowChoice.values)
              FilterChip(
                label: Text(w.label(l10n)),
                selected: w == WindowChoice.anytime
                    ? value.allDay
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
        if (recurring || !value.allDay)
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
                    _summary(context, l10n),
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

/// A one-field dialog for "open for N days" (1…365).
Future<int?> _askDays(BuildContext context, int initial) async {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController(text: '$initial');
  final result = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.windowOpenFor),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          suffixText: l10n.windowDays(2).split(' ').last,
        ),
        onSubmitted: (_) =>
            Navigator.pop(ctx, int.tryParse(controller.text.trim())),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(ctx, int.tryParse(controller.text.trim())),
          child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result == null) return null;
  return result.clamp(1, 365);
}
