import 'dart:math' as math;

import 'package:flutter/material.dart';

class Entrance extends StatelessWidget {
  const Entrance({super.key, required this.child, this.delay = 0});
  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final total = 320 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      child: child,
      builder: (context, value, child) {
        final progress = Curves.easeOutCubic.transform(
          ((value * total - delay) / 320).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - progress)),
            child: child,
          ),
        );
      },
    );
  }
}

/// A short, restrained transition for pushed screens; keeps native back navigation.
class TrustPageTransitions extends PageTransitionsBuilder {
  const TrustPageTransitions();
  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 320);
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = animation.drive(CurveTween(curve: Curves.easeInOutCubic));
    return FadeTransition(
      opacity: animation.drive(
        CurveTween(curve: const Interval(0, .75, curve: Curves.easeOutCubic)),
      ),
      child: SlideTransition(
        position: curved.drive(
          Tween(begin: const Offset(0, .018), end: Offset.zero),
        ),
        child: child,
      ),
    );
  }
}

/// Cross-fades tabs without exposing outgoing controls to taps or screen readers.
class TabTransition extends StatelessWidget {
  const TabTransition({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 320),
      reverseDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: animation.drive(
            Tween(begin: const Offset(0, .012), end: Offset.zero),
          ),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [
          for (final outgoing in previous)
            ExcludeFocus(
              child: ExcludeSemantics(child: IgnorePointer(child: outgoing)),
            ),
          ?current,
        ],
      ),
      child: KeyedSubtree(key: ValueKey(index), child: child),
    ),
  );
}

/// Keeps the Navigator mounted throughout the reveal, preserving route/form state.
class LaunchIntro extends StatefulWidget {
  const LaunchIntro({
    super.key,
    required this.child,
    required this.onComplete,
    this.enabled = true,
  });
  final Widget child;
  final VoidCallback onComplete;
  final bool enabled;
  @override
  State<LaunchIntro> createState() => _LaunchIntroState();
}

class _LaunchIntroState extends State<LaunchIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  bool done = false;
  bool completionQueued = false;

  @override
  void initState() {
    super.initState();
    done = !widget.enabled;
    controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) finish();
          });
    if (!done) controller.forward();
  }

  void finish() {
    if (completionQueued || done) return;
    completionQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => done = true);
      widget.onComplete();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.stop();
      finish();
    }
  }

  @override
  void didUpdateWidget(LaunchIntro oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      done = true;
      controller.stop();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final accent = dark ? const Color(0xFF81E3BD) : const Color(0xFF0B6E4F);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final reveal = const Interval(
          .70,
          1,
          curve: Curves.easeInOutCubic,
        ).transform(t);
        final showing = !done && !reduced;
        return Stack(
          fit: StackFit.expand,
          children: [
            TickerMode(
              enabled: !showing || t >= .70,
              child: ExcludeFocus(
                excluding: showing,
                child: ExcludeSemantics(
                  excluding: showing,
                  child: IgnorePointer(ignoring: showing, child: widget.child),
                ),
              ),
            ),
            if (showing)
              Positioned.fill(
                child: Opacity(
                  opacity: 1 - reveal,
                  child: Material(
                    key: const ValueKey('launch-intro'),
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -.18),
                          radius: .85,
                          colors: [
                            accent.withValues(alpha: dark ? .09 : .055),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Stack(
                          children: [
                            Center(
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 24,
                                  ),
                                  child: Transform.translate(
                                    offset: Offset(0, -8 * reveal),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        RepaintBoundary(
                                          child: SizedBox(
                                            width: 138,
                                            height: 138,
                                            child: CustomPaint(
                                              painter: _TrustMark(
                                                t,
                                                accent,
                                                colors.outlineVariant,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 25),
                                        _reveal(
                                          t,
                                          .20,
                                          .57,
                                          Text(
                                            'ثقة',
                                            style: Theme.of(context)
                                                .textTheme
                                                .displaySmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  color: colors.onSurface,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(height: 9),
                                        _reveal(
                                          t,
                                          .30,
                                          .63,
                                          Text(
                                            'THIQAH',
                                            textDirection: TextDirection.ltr,
                                            style: TextStyle(
                                              letterSpacing: 5,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: accent,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 23),
                                        _reveal(
                                          t,
                                          .38,
                                          .68,
                                          Text(
                                            Localizations.localeOf(context)
                                                        .languageCode ==
                                                    'ar'
                                                ? 'كل خطوة، بثقة'
                                                : 'Confidence in every step',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: colors.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _reveal(double t, double start, double end, Widget child) {
    final v = Interval(start, end, curve: Curves.easeOutCubic).transform(t);
    return Opacity(
      opacity: v,
      child: Transform.translate(offset: Offset(0, 9 * (1 - v)), child: child),
    );
  }
}

/// Vector-drawn shield and check: no images, network requests or looping effects.
class _TrustMark extends CustomPainter {
  _TrustMark(this.progress, this.color, this.outline);
  final double progress;
  final Color color, outline;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 138, size.height / 138);
    final enter = const Interval(
      0,
      .44,
      curve: Curves.easeOutCubic,
    ).transform(progress);
    final trace = const Interval(
      .06,
      .48,
      curve: Curves.easeInOutCubic,
    ).transform(progress);
    final check = const Interval(
      .36,
      .62,
      curve: Curves.easeOutCubic,
    ).transform(progress);
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(9, 9, 120, 120),
      const Radius.circular(35),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = color.withValues(alpha: .075 * enter),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: .15 * enter),
    );
    canvas.drawArc(
      const Rect.fromLTWH(1, 1, 136, 136),
      -math.pi / 2,
      math.pi * 2 * trace,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = outline.withValues(alpha: .40 * enter),
    );
    final shield = Path()
      ..moveTo(69, 33)
      ..cubicTo(80, 41, 91, 44, 99, 46)
      ..lineTo(99, 67)
      ..cubicTo(99, 86, 84, 99, 69, 107)
      ..cubicTo(54, 99, 39, 86, 39, 67)
      ..lineTo(39, 46)
      ..cubicTo(47, 44, 58, 41, 69, 33)
      ..close();
    canvas.drawPath(
      shield,
      Paint()..color = color.withValues(alpha: .06 * enter),
    );
    _stroke(canvas, shield, trace, 3);
    _stroke(
      canvas,
      Path()
        ..moveTo(55, 68)
        ..lineTo(65, 78)
        ..lineTo(84, 58),
      check,
      4,
    );
    canvas.restore();
  }

  void _stroke(Canvas canvas, Path path, double amount, double width) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * amount), paint);
    }
  }

  @override
  bool shouldRepaint(_TrustMark oldDelegate) =>
      progress != oldDelegate.progress ||
      color != oldDelegate.color ||
      outline != oldDelegate.outline;
}
