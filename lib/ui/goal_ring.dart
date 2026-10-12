import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/goal.dart';
import '../domain/task.dart';
import '../l10n/app_localizations.dart';

/// The counter marker (DESIGN_SYSTEM §2, mockup `10-counter.html`): one arc
/// segment per check-in slot up to `max` (or `min` with no limit), the filled
/// ones in [color]. Past the minimum of a no-limit goal the ring is full and
/// carries the count. An ordinary 1-of-1 habit never uses this — it keeps
/// the plain ring/check icons.
class GoalRing extends StatelessWidget {
  const GoalRing({
    super.key,
    required this.count,
    required this.goal,
    required this.color,
    this.size = 24,
  });

  final int count;
  final Goal goal;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GoalRingPainter(
        count: count,
        goal: goal,
        color: color,
        textStyle: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _GoalRingPainter extends CustomPainter {
  _GoalRingPainter({
    required this.count,
    required this.goal,
    required this.color,
    required this.textStyle,
  });

  final int count;
  final Goal goal;
  final Color color;
  final TextStyle? textStyle;

  /// More slots than this read as a smooth progress arc, not segments.
  static const _maxSegments = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final slots = goal.max ?? goal.min;
    final filled = math.min(count, slots);
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    final on = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .13
      ..strokeCap = StrokeCap.round;
    final off = Paint()
      ..color = color.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .08
      ..strokeCap = StrokeCap.round;
    const top = -math.pi / 2;

    if (slots > _maxSegments) {
      canvas.drawCircle(c, r, off);
      if (filled > 0) {
        canvas.drawArc(rect, top, 2 * math.pi * filled / slots, false, on);
      }
    } else {
      final gap = slots > 1 ? .32 : 0.0;
      final sweep = 2 * math.pi / slots;
      for (var i = 0; i < slots; i++) {
        canvas.drawArc(
          rect,
          top + i * sweep + gap / 2,
          sweep - gap,
          false,
          i < filled ? on : off,
        );
      }
    }

    // No limit and past the minimum: the count rides inside the full ring.
    if (goal.max == null && count >= goal.min) {
      final tp = TextPainter(
        text: TextSpan(
          text: '$count',
          style: (textStyle ?? const TextStyle()).copyWith(
            color: color,
            fontSize: size.width * (count > 99 ? .3 : .4),
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_GoalRingPainter old) =>
      old.count != count || old.goal != goal || old.color != color;
}

/// The goal as a span: "2", "2–3", "8+" (no limit).
String goalSpan(Goal g) => g.max == null
    ? '${g.min}+'
    : g.max == g.min
    ? '${g.min}'
    : '${g.min}–${g.max}';

/// The progress pill's text (DESIGN_SYSTEM §3.6): "1 / 2", "1 / 2–3", and
/// past the minimum of a no-limit goal "9 · no limit".
String goalProgressLabel(AppLocalizations l10n, Task t) =>
    t.goal.max == null && t.isMet
    ? l10n.goalNoLimitCount(t.count)
    : '${t.count} / ${goalSpan(t.goal)}';
