import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuchsbau/fuchsbau.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../domain/stats.dart';
import '../domain/task.dart';
import '../l10n/app_localizations.dart';
import '../providers.dart';
import 'stats_tiles.dart';
import 'stats_tiles_screen.dart';

final _tasksProvider = StreamProvider.autoDispose<List<Task>>(
  (ref) => ref.watch(taskRepositoryProvider).watchTasks(),
);

final _templateNamesProvider = StreamProvider.autoDispose<Map<int, String>>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  return db
      .select(db.templates)
      .watch()
      .map((rows) => {for (final r in rows) r.id: r.name});
});

/// Stats: a column of tiles in the user's order (Settings → tiles), each a
/// card with an uppercase title. Only *done* wears colour; every day state
/// also differs by shape (DESIGN_SYSTEM §2 — a miss is never red).
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tasks = ref.watch(_tasksProvider).asData?.value;
    final names = ref.watch(_templateNamesProvider).asData?.value;
    final tiles = enabledTiles(ref.watch(settingsProvider).effectiveStatsTiles);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statsTitle),
        actions: [
          IconButton(
            tooltip: l10n.statsEditTiles,
            icon: const Icon(Symbols.tune_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StatsTilesScreen()),
            ),
          ),
        ],
      ),
      body: (tasks == null || names == null)
          ? const Center(child: CircularProgressIndicator())
          : _Tiles(
              summary: computeStatsSummary(
                tasks,
                names,
                ref.read(clockProvider).now(),
              ),
              tiles: tiles,
            ),
    );
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles({required this.summary, required this.tiles});

  final StatsSummary summary;
  final List<StatsTile> tiles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!summary.hasHabits) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.statsNoHabits,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      children: [
        for (final t in tiles)
          _Tile(
            key: ValueKey(t.id),
            title: t.title(l10n),
            trailing: switch (t) {
              StatsTile.week => _weekRange(context),
              StatsTile.byWindow => l10n.statsDoneRate30,
              StatsTile.heatmap ||
              StatsTile.missesByWeekday => l10n.statsLast30Days,
              _ => null,
            },
            child: switch (t) {
              StatsTile.completion => _CompletionTile(summary),
              StatsTile.week => _WeekTile(summary),
              StatsTile.streaks => _StreaksTile(summary),
              StatsTile.insight => _InsightTile(summary),
              StatsTile.heatmap => _HeatmapTile(summary),
              StatsTile.byWindow => _ByWindowTile(summary),
              StatsTile.missesByWeekday => _MissesTile(summary),
            },
          ),
      ],
    );
  }

  String _weekRange(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final f = DateFormat.MMMd(locale);
    final end = summary.weekStart.add(const Duration(days: 6));
    return '${f.format(summary.weekStart)} – ${f.format(end)}';
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final String? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return FuchsbauSettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.outline,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .6,
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Text(
                      trailing!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.outline,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Marks

/// One day: shape + colour, never colour alone.
class DayMarkDot extends StatelessWidget {
  const DayMarkDot(this.mark, {super.key, this.size = 14});

  final DayMark mark;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = FuchsbauStatusColors.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DayMarkPainter(
          mark,
          done: scheme.tertiary,
          onDone: scheme.onTertiary,
          skipped: status.neutral,
          missed: status.taupe,
          open: scheme.primary,
          none: scheme.outlineVariant,
        ),
      ),
    );
  }
}

class _DayMarkPainter extends CustomPainter {
  const _DayMarkPainter(
    this.mark, {
    required this.done,
    required this.onDone,
    required this.skipped,
    required this.missed,
    required this.open,
    required this.none,
  });

  final DayMark mark;
  final Color done, onDone, skipped, missed, open, none;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    switch (mark) {
      case DayMark.done:
        canvas.drawCircle(c, r, Paint()..color = done);
        final p = Path()
          ..moveTo(c.dx - r * .42, c.dy + r * .02)
          ..lineTo(c.dx - r * .1, c.dy + r * .36)
          ..lineTo(c.dx + r * .46, c.dy - r * .34);
        canvas.drawPath(
          p,
          Paint()
            ..color = onDone
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      case DayMark.skipped:
        canvas.drawCircle(c, r - 1, stroke..color = skipped);
        canvas.drawLine(
          Offset(c.dx - r * .5, c.dy),
          Offset(c.dx + r * .5, c.dy),
          stroke,
        );
      case DayMark.missed:
        stroke.color = missed;
        final path = Path()..addOval(Rect.fromCircle(center: c, radius: r - 1));
        for (final m in path.computeMetrics()) {
          var d = 0.0;
          while (d < m.length) {
            canvas.drawPath(m.extractPath(d, d + 2.6), stroke);
            d += 4.6;
          }
        }
      case DayMark.open:
        canvas.drawCircle(c, r - 1, stroke..color = open);
      case DayMark.none:
        canvas.drawCircle(
          c,
          r - 1,
          stroke
            ..color = none
            ..strokeWidth = 1.2,
        );
    }
  }

  @override
  bool shouldRepaint(_DayMarkPainter old) =>
      old.mark != mark || old.done != done || old.none != none;
}

// ---------------------------------------------------------------------------
// Tiles

String _pct(double? r) => r == null ? '—' : '${(r * 100).round()}%';

class _CompletionTile extends StatelessWidget {
  const _CompletionTile(this.s);
  final StatsSummary s;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    Widget stat(String label, double? rate) => Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _pct(rate),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            stat(l10n.statsLast7Days, s.rate7),
            const SizedBox(width: 8),
            stat(l10n.statsLast30Days, s.rate30),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l10n.statsWeekBreakdown(
            s.done7,
            s.skipped7,
            s.missed7,
            s.done7 + s.skipped7 + s.missed7,
          ),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.outline),
        ),
      ],
    );
  }
}

class _WeekTile extends StatelessWidget {
  const _WeekTile(this.s);
  final StatsSummary s;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final dayF = DateFormat.E(locale);
    const gap = 6.0;
    Widget marks(List<Widget> cells, Widget tail) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: gap),
          cells[i],
        ],
        const SizedBox(width: 10),
        SizedBox(width: 34, child: tail),
      ],
    );
    final countStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.outline,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Spacer(),
            marks([
              for (var i = 0; i < 7; i++)
                SizedBox(
                  width: 14,
                  child: Text(
                    dayF
                        .format(s.weekStart.add(Duration(days: i)))
                        .characters
                        .first,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.outline,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ], const SizedBox.shrink()),
          ],
        ),
        for (final h in s.week) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    h.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                marks(
                  [for (final m in h.days) DayMarkDot(m)],
                  Text(
                    '${h.done}/${h.resolved}',
                    textAlign: TextAlign.right,
                    style: countStyle,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final (m, label) in [
              (DayMark.done, l10n.statsLegendDone),
              (DayMark.skipped, l10n.statsLegendSkipped),
              (DayMark.missed, l10n.statsLegendMissed),
              (DayMark.open, l10n.statsLegendOpen),
              (DayMark.none, l10n.statsLegendNoWindow),
            ])
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DayMarkDot(m, size: 11),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _StreaksTile extends StatelessWidget {
  const _StreaksTile(this.s);
  final StatsSummary s;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        for (var i = 0; i < s.streaks.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  Symbols.local_fire_department_rounded,
                  size: 20,
                  fill: s.streaks[i].current > 0 ? 1 : 0,
                  color: s.streaks[i].current > 0
                      ? scheme.primary
                      : scheme.outline,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.streaks[i].name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${s.streaks[i].current}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      TextSpan(
                        text: '  ${l10n.statsStreakDays(s.streaks[i].best)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.outline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile(this.s);
  final StatsSummary s;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final text = switch (s.insight) {
      WeakestWindowInsight(:final window, :final rate) =>
        l10n.statsInsightWeakWindow(_windowLabel(l10n, window), _pct(rate)),
      BestWeekdayInsight(:final weekday) => l10n.statsInsightBestWeekday(
        DateFormat.EEEE(locale).format(DateTime(2026, 6, 1 + weekday - 1)),
      ),
      NoInsight() => l10n.statsInsightNone,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Symbols.lightbulb_rounded, color: scheme.secondary, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    );
  }
}

String _windowLabel(AppLocalizations l10n, StatsWindow w) => switch (w) {
  StatsWindow.night => l10n.windowNight,
  StatsWindow.morning => l10n.windowMorning,
  StatsWindow.afternoon => l10n.windowAfternoon,
  StatsWindow.evening => l10n.windowEvening,
};

IconData _windowIcon(StatsWindow w) => switch (w) {
  StatsWindow.night => Symbols.bedtime_rounded,
  StatsWindow.morning => Symbols.wb_twilight_rounded,
  StatsWindow.afternoon => Symbols.light_mode_rounded,
  StatsWindow.evening => Symbols.nights_stay_rounded,
};

class _HeatmapTile extends StatelessWidget {
  const _HeatmapTile(this.s);
  final StatsSummary s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = FuchsbauStatusColors.of(context);
    // Single-hue emerald: done = full step; skipped / missed sit on the
    // neutral status colours at low alpha; empty = the surface tint.
    Color cell(DayMark m) => switch (m) {
      DayMark.done => scheme.tertiary,
      DayMark.open => scheme.primary.withValues(alpha: .35),
      DayMark.skipped => status.neutral.withValues(alpha: .35),
      DayMark.missed => status.taupe.withValues(alpha: .35),
      DayMark.none => scheme.surfaceContainerHighest,
    };
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 3.0;
        final size = ((c.maxWidth - gap * 29) / 30).clamp(6.0, 14.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < s.heat.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Text(
                s.heat[i].name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (var d = 0; d < 30; d++) ...[
                    if (d > 0) const SizedBox(width: gap),
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: cell(s.heat[i].days[d]),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ByWindowTile extends StatelessWidget {
  const _ByWindowTile(this.s);
  final StatsSummary s;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        for (final w in StatsWindow.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(_windowIcon(w), size: 16, color: scheme.outline),
                const SizedBox(width: 6),
                SizedBox(
                  width: 82,
                  child: Text(
                    _windowLabel(l10n, w),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(4),
                    ),
                    child: SizedBox(
                      height: 10,
                      child: Stack(
                        children: [
                          Container(color: scheme.surfaceContainerHighest),
                          FractionallySizedBox(
                            widthFactor: (s.byWindow[w] ?? 0).clamp(0.0, 1.0),
                            child: Container(color: scheme.tertiary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 36,
                  child: Text(
                    _pct(s.byWindow[w]),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.outline,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MissesTile extends StatelessWidget {
  const _MissesTile(this.s);
  final StatsSummary s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = FuchsbauStatusColors.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dayF = DateFormat.E(locale);
    final max = s.missesByWeekday.fold(0, math.max);
    // The two worst days wear amber — information, never alarm.
    final sorted = [for (var i = 0; i < 7; i++) i]
      ..sort((a, b) => s.missesByWeekday[b].compareTo(s.missesByWeekday[a]));
    final worst = {
      for (final i in sorted.take(2))
        if (s.missesByWeekday[i] > 0) i,
    };
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.outline,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${s.missesByWeekday[i]}', style: labelStyle),
                  const SizedBox(height: 3),
                  Container(
                    height: max == 0 ? 2 : 4 + 56 * s.missesByWeekday[i] / max,
                    decoration: BoxDecoration(
                      color: worst.contains(i) ? status.amber : status.taupe,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayF.format(DateTime(2026, 6, 1 + i)).characters.first,
                    style: labelStyle,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
