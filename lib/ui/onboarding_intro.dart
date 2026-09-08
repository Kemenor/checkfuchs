import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../l10n/app_localizations.dart';

/// First-launch intro pager (examples/ui/08-onboarding-intro.html): three
/// ideas — Task, Lens, View — one page each, then straight into the carrier
/// habit sheet. Illustrations are the app's own shapes (ring + row + pill,
/// the dashed lens outline, the tabbed screen) so what the user sees here is
/// what they meet on Home. Text-free illustrations: nothing to translate.
/// Skip is always available; nothing here is required.
Future<void> showOnboardingIntro(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const OnboardingIntroScreen(),
    ),
  );
}

class OnboardingIntroScreen extends StatefulWidget {
  const OnboardingIntroScreen({super.key});

  @override
  State<OnboardingIntroScreen> createState() => _OnboardingIntroScreenState();
}

class _OnboardingIntroScreenState extends State<OnboardingIntroScreen> {
  final _pages = PageController();
  int _index = 0;

  static const _count = 3;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_index >= _count - 1) {
      Navigator.of(context).pop();
      return;
    }
    _pages.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final last = _index == _count - 1;

    final pages = [
      _IntroPage(
        eyebrow: l10n.introTaskEyebrow,
        title: l10n.introTaskTitle,
        body: l10n.introTaskBody,
        illustration: const _TaskIllustration(),
      ),
      _IntroPage(
        eyebrow: l10n.introLensEyebrow,
        title: l10n.introLensTitle,
        body: l10n.introLensBody,
        illustration: const _LensIllustration(),
      ),
      _IntroPage(
        eyebrow: l10n.introViewEyebrow,
        title: l10n.introViewTitle,
        body: l10n.introViewBody,
        illustration: const _ViewIllustration(),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 8, 0),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.introSkip),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _index = i),
                children: pages,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _count; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _index ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? scheme.secondary
                                : scheme.outlineVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _next,
                    icon: const Icon(Symbols.arrow_forward_rounded),
                    iconAlignment: IconAlignment.end,
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(last ? l10n.introStart : l10n.introNext),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.illustration,
  });

  final String eyebrow;
  final String title;
  final String body;
  final Widget illustration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 250, child: Center(child: illustration)),
          const SizedBox(height: 28),
          Text(
            eyebrow.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.secondary,
              fontWeight: FontWeight.w700,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 8),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.outline,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Illustrations — the app's own shapes, no text.

/// A task row: the tap ring, a name bar, a when-pill.
class _TaskRow extends StatelessWidget {
  const _TaskRow({this.done = false, this.nameWidth = 96, this.faded = false});

  final bool done;
  final double nameWidth;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = faded ? scheme.outlineVariant : scheme.outline;
    return Row(
      children: [
        if (done)
          Icon(Symbols.check_circle_rounded, color: scheme.tertiary, size: 26)
        else
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: faded ? scheme.outlineVariant : scheme.primary,
                width: 2.5,
              ),
            ),
          ),
        const SizedBox(width: 14),
        Container(
          width: nameWidth,
          height: 10,
          decoration: BoxDecoration(
            color: done ? scheme.outlineVariant : ink,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const Spacer(),
        if (!done)
          Container(
            width: 44,
            height: 18,
            decoration: BoxDecoration(
              color: faded
                  ? scheme.surfaceContainerHighest
                  : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(9),
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.width = 260,
    this.header = false,
    this.compact = false,
  });

  final Widget child;
  final double width;
  final bool header;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      padding: compact
          ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
          : const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(compact ? 14 : 18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header) ...[
            Row(
              children: [
                Container(
                  width: 70,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.outline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Spacer(),
                Icon(Symbols.add_rounded, size: 16, color: scheme.outline),
              ],
            ),
            SizedBox(height: compact ? 8 : 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _TaskIllustration extends StatelessWidget {
  const _TaskIllustration();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Column(
        children: [
          _TaskRow(nameWidth: 110),
          SizedBox(height: 18),
          _TaskRow(done: true, nameWidth: 80),
        ],
      ),
    );
  }
}

/// Dashed indigo outline around the picked rows; the rest sits faded outside.
class _LensIllustration extends StatelessWidget {
  const _LensIllustration();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 260,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _TaskRow(faded: true, nameWidth: 70),
          ),
          const SizedBox(height: 10),
          CustomPaint(
            painter: _DashedRectPainter(color: scheme.secondary),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Symbols.filter_alt_rounded,
                        size: 16,
                        color: scheme.secondary,
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 56,
                        height: 8,
                        decoration: BoxDecoration(
                          color: scheme.secondary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _TaskRow(nameWidth: 104),
                  const SizedBox(height: 14),
                  const _TaskRow(nameWidth: 84),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _TaskRow(faded: true, nameWidth: 90),
          ),
        ],
      ),
    );
  }
}

/// A mini screen: two lens cards stacked over a three-tab bar.
class _ViewIllustration extends StatelessWidget {
  const _ViewIllustration();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget tab(IconData icon, {bool active = false}) => Container(
      width: 44,
      height: 26,
      decoration: BoxDecoration(
        color: active ? scheme.secondaryContainer : null,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        icon,
        size: 16,
        color: active ? scheme.onSecondaryContainer : scheme.outline,
      ),
    );
    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Card(
            width: 200,
            header: true,
            compact: true,
            child: Column(
              children: [
                _TaskRow(nameWidth: 70),
                SizedBox(height: 8),
                _TaskRow(nameWidth: 54),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const _Card(
            width: 200,
            header: true,
            compact: true,
            child: _TaskRow(nameWidth: 62),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              tab(Symbols.home_rounded, active: true),
              tab(Symbols.event_repeat_rounded),
              tab(Symbols.inbox_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(18),
    );
    final path = Path()..addRRect(rrect);
    const dash = 7.0, gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) => old.color != color;
}
