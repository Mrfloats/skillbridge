import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// Shared timing, so everything in the app moves with the same rhythm.
class Motion {
  static const fast = Duration(milliseconds: 170);
  static const medium = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 620);
  static const emphasized = Cubic(0.2, 0, 0, 1);
  static const overshoot = Cubic(0.34, 1.45, 0.64, 1);

  /// True when the person has asked the system to reduce animations.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Fades and slides its child in once. Use [index] to stagger items in a list.
class Reveal extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  final Offset offset;
  final bool animate;
  const Reveal({super.key, required this.child, this.index = 0, this.delay = Duration.zero, this.offset = const Offset(0, 18), this.animate = true});

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  static const _stagger = 55;
  static const _maxStagger = 7;

  late final AnimationController _controller;
  late final Animation<double> _progress;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final delayMs = widget.delay.inMilliseconds + math.min(widget.index, _maxStagger) * _stagger;
    final totalMs = delayMs + Motion.slow.inMilliseconds;
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: totalMs));
    _progress = CurvedAnimation(parent: _controller, curve: Interval(delayMs / totalMs, 1, curve: Motion.emphasized));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final skip = !widget.animate || widget.index > _maxStagger || Motion.reduced(context);
    if (skip) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _progress,
        child: widget.child,
        builder: (context, child) {
          final t = _progress.value;
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(offset: widget.offset * (1 - t), child: child),
          );
        },
      );
}

/// The main interactive surface. With a mouse it lifts, grows its shadow,
/// highlights its border and follows the pointer with a soft spotlight. On touch
/// it scales down while pressed. It also shows a ring for keyboard focus.
class HoverCard extends StatefulWidget {
  final Widget? child;
  final Widget Function(BuildContext context, bool hovered)? builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? color;
  final Gradient? gradient;
  final bool outlined;
  final bool spotlight;
  final bool hoverable;
  final Color? spotlightColor;
  final double lift;

  const HoverCard({
    super.key,
    this.child,
    this.builder,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.color,
    this.gradient,
    this.outlined = true,
    this.spotlight = true,
    this.hoverable = false,
    this.spotlightColor,
    this.lift = 4,
  }) : assert(child != null || builder != null);

  @override
  State<HoverCard> createState() => HoverCardState();
}

class HoverCardState extends State<HoverCard> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;
  final _pointer = ValueNotifier<Offset?>(null);

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;
  bool get _responds => _interactive || widget.hoverable;

  /// Whether a mouse is currently over this card and it is responding.
  bool get isHovered => _responds && _hovered;

  /// Where the spotlight is centred, or null when no mouse is over the card.
  Offset? get spotlightPosition => _pointer.value;

  @override
  void dispose() {
    _pointer.dispose();
    super.dispose();
  }

  void _setHovered(bool value) {
    if (_hovered != value) setState(() => _hovered = value);
    if (!value) _pointer.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final palette = context.palette;
    final reduced = Motion.reduced(context);
    final hovered = isHovered;
    final scale = _pressed ? 0.975 : (hovered && !reduced ? 1.008 : 1.0);
    final lift = hovered && !reduced ? -widget.lift : 0.0;
    final hasFill = widget.gradient != null || widget.color != null;
    final borderColor = _focused
        ? c.primary
        : hovered
            ? c.primary.withAlpha(hasFill ? 0 : 150)
            : (widget.outlined && !hasFill ? c.outlineVariant : Colors.transparent);
    final darkMode = c.brightness == Brightness.dark;

    Widget content = Padding(
      padding: widget.padding,
      child: widget.child ?? widget.builder!(context, hovered),
    );
    if (widget.spotlight && _responds) {
      content = CustomPaint(
        foregroundPainter: _SpotlightPainter(
          _pointer,
          (widget.spotlightColor ?? (hasFill ? Colors.white : c.primary)).withAlpha(hasFill || darkMode ? 34 : 18),
        ),
        child: content,
      );
    }

    return MouseRegion(
      cursor: _interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      onHover: (e) => _pointer.value = e.localPosition,
      child: AnimatedScale(
        scale: scale,
        duration: Motion.fast,
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.emphasized,
          transform: Matrix4.translationValues(0, lift, 0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: widget.gradient == null ? (widget.color ?? c.surfaceContainerLowest) : null,
            gradient: widget.gradient,
            borderRadius: widget.borderRadius,
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: palette.shadow.withAlpha(hovered ? (darkMode ? 130 : 46) : (hasFill ? 26 : 8)),
                blurRadius: hovered ? 30 : 12,
                offset: Offset(0, hovered ? 16 : 4),
              ),
              if (_focused) BoxShadow(color: c.primary.withAlpha(90), spreadRadius: 3),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: _interactive
                ? InkWell(
                    borderRadius: widget.borderRadius,
                    onTap: widget.onTap == null
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            widget.onTap!();
                          },
                    onLongPress: widget.onLongPress,
                    onHighlightChanged: (v) => setState(() => _pressed = v),
                    onFocusChange: (v) => setState(() => _focused = v),
                    child: content,
                  )
                : content,
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final ValueNotifier<Offset?> pointer;
  final Color color;
  _SpotlightPainter(this.pointer, this.color) : super(repaint: pointer);

  @override
  void paint(Canvas canvas, Size size) {
    final p = pointer.value;
    if (p == null) return;
    final radius = math.max(size.shortestSide, 180.0);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = RadialGradient(colors: [color, color.withAlpha(0)]).createShader(Rect.fromCircle(center: p, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.color != color;
}

/// The primary call to action: an amber gradient button. On hover it lifts,
/// glows and sweeps a band of light across its face.
class GlowButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  const GlowButton({super.key, required this.label, this.icon, this.onPressed, this.busy = false});

  @override
  State<GlowButton> createState() => GlowButtonState();
}

class GlowButtonState extends State<GlowButton> with SingleTickerProviderStateMixin {
  late final AnimationController _sheen = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  /// Whether the band of light is crossing the button right now.
  bool get isSheenRunning => _sheen.isAnimating;

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
    if (value && !Motion.reduced(context)) _sheen.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final c = Theme.of(context).colorScheme;
    final enabled = widget.onPressed != null && !widget.busy;
    final hovered = enabled && _hovered;
    final reduced = Motion.reduced(context);
    final foreground = enabled ? palette.onAccent : c.onSurface.withAlpha(120);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.busy ? '${widget.label}, working' : widget.label,
      onTap: enabled ? widget.onPressed : null,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: Motion.fast,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.emphasized,
            height: 56,
            transform: Matrix4.translationValues(0, hovered && !reduced ? -3 : 0, 0),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: enabled ? palette.accentGradient : null,
              color: enabled ? null : c.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                if (enabled)
                  BoxShadow(
                    color: palette.accent.withAlpha(hovered ? 150 : 50),
                    blurRadius: hovered ? 30 : 14,
                    offset: Offset(0, hovered ? 12 : 5),
                  ),
                if (_focused) BoxShadow(color: c.primary.withAlpha(150), spreadRadius: 3),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: enabled
                    ? () {
                        HapticFeedback.lightImpact();
                        widget.onPressed!();
                      }
                    : null,
                onHighlightChanged: (v) => setState(() => _pressed = v),
                onFocusChange: (v) => setState(() => _focused = v),
                child: AnimatedBuilder(
                  animation: _sheen,
                  builder: (context, child) => CustomPaint(foregroundPainter: _SheenPainter(_sheen.value), child: child),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: Motion.medium,
                      switchInCurve: Motion.emphasized,
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(scale: Tween<double>(begin: 0.85, end: 1).animate(a), child: child),
                      ),
                      child: widget.busy
                          ? SizedBox(
                              key: const ValueKey('busy'),
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.6, color: c.onSurface),
                            )
                          : Row(
                              key: const ValueKey('label'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.icon != null) ...[Icon(widget.icon, size: 20, color: foreground), const SizedBox(width: 8)],
                                Flexible(
                                  child: Text(
                                    widget.label,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: foreground, fontSize: 16, fontWeight: FontWeight.w800),
                                  ),
                                ),
                                if (widget.icon == null && enabled) ...[
                                  AnimatedContainer(
                                    duration: Motion.medium,
                                    curve: Motion.emphasized,
                                    width: hovered ? 12 : 6,
                                  ),
                                  Icon(Icons.arrow_forward_rounded, size: 19, color: foreground),
                                ],
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheenPainter extends CustomPainter {
  final double t;
  _SheenPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final x = -size.width * 0.4 + (size.width * 1.8) * Curves.easeInOut.transform(t);
    final band = Rect.fromLTWH(x, 0, size.width * 0.4, size.height);
    canvas.drawRect(
      band,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment(-1, -0.4),
          end: Alignment(1, 0.4),
          colors: [Color(0x00FFFFFF), Color(0x8CFFFFFF), Color(0x00FFFFFF)],
        ).createShader(band),
    );
  }

  @override
  bool shouldRepaint(_SheenPainter old) => old.t != t;
}

/// Rolls a number up to its value, and on to any new value it receives.
class CountUp extends StatelessWidget {
  final double value;
  final String Function(double value) format;
  final TextStyle? style;
  const CountUp({super.key, required this.value, required this.format, this.style});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value),
        duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Text(
          format(v),
          semanticsLabel: format(value),
          style: (style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      );
}

/// Sweeps a highlight across its child. Wraps placeholder shapes while loading.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final x = -1.5 + 3 * _c.value;
            return LinearGradient(
              begin: Alignment(x - 0.6, 0),
              end: Alignment(x + 0.6, 0),
              colors: [c.surfaceContainerHigh, c.surfaceContainerLowest, c.surfaceContainerHigh],
            ).createShader(rect);
          },
          child: child,
        ),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(radius)),
      );
}

/// Placeholder rows shown while a list loads, shaped like the content to come.
class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading',
        liveRegion: true,
        child: ExcludeSemantics(
          child: Shimmer(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: count,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(20)),
                child: const Row(children: [
                  SkeletonBox(width: 56, height: 56, radius: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SkeletonBox(width: 150, height: 14),
                      SizedBox(height: 10),
                      SkeletonBox(width: 90, height: 11),
                      SizedBox(height: 10),
                      SkeletonBox(height: 11),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Like IndexedStack, keeping every page's state, but cross-fades between pages.
class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const FadeIndexedStack({super.key, required this.index, required this.children});

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.medium, value: 1);
  late final Animation<double> _curve = CurvedAnimation(parent: _c, curve: Motion.emphasized);
  static const _settled = AlwaysStoppedAnimation<double>(1);

  @override
  void didUpdateWidget(FadeIndexedStack old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index && !Motion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      for (var i = 0; i < widget.children.length; i++)
        Offstage(
          offstage: i != widget.index,
          child: TickerMode(
            enabled: i == widget.index,
            child: FadeTransition(
              opacity: i == widget.index ? _curve : _settled,
              child: SlideTransition(
                position: (i == widget.index ? _curve : _settled).drive(Tween<Offset>(begin: const Offset(0, 0.012), end: Offset.zero)),
                child: widget.children[i],
              ),
            ),
          ),
        ),
    ]);
  }
}

/// Deep teal gradient with soft light blobs. When [animate] is set the blobs drift
/// slowly, so keep that for full-screen moments rather than long-lived screens.
class Aurora extends StatefulWidget {
  final Widget child;
  final bool animate;
  final BorderRadius? borderRadius;
  const Aurora({super.key, required this.child, this.animate = false, this.borderRadius});

  @override
  State<Aurora> createState() => _AuroraState();
}

class _AuroraState extends State<Aurora> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 16));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.animate || Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: palette.heroGradient),
        child: Stack(children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _AuroraPainter(_c, palette.accent)),
            ),
          ),
          widget.child,
        ]),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final Animation<double> t;
  final Color accent;
  _AuroraPainter(this.t, this.accent) : super(repaint: t);

  void _blob(Canvas canvas, Size size, Offset center, double radius, Color color) {
    final o = Offset(center.dx * size.width, center.dy * size.height);
    final r = radius * size.longestSide;
    canvas.drawCircle(o, r, Paint()..shader = RadialGradient(colors: [color, color.withAlpha(0)]).createShader(Rect.fromCircle(center: o, radius: r)));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final a = t.value * 2 * math.pi;
    _blob(canvas, size, Offset(0.88 + 0.08 * math.sin(a), 0.1 + 0.06 * math.cos(a)), 0.42, const Color(0x8816908A));
    _blob(canvas, size, Offset(0.05 + 0.08 * math.cos(a), 0.62 + 0.07 * math.sin(a)), 0.4, const Color(0x4439C4BB));
    _blob(canvas, size, Offset(0.62 + 0.09 * math.sin(a + 2), 1.02 + 0.04 * math.cos(a + 2)), 0.32, accent.withAlpha(22));
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.accent != accent;
}

/// Radiates a ring from its child to draw attention. Used by the SOS button.
class PulseRing extends StatefulWidget {
  final Widget child;
  final Color color;
  const PulseRing({super.key, required this.child, required this.color});

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _PulsePainter(_c, widget.color), child: widget.child);
}

class _PulsePainter extends CustomPainter {
  final Animation<double> t;
  final Color color;
  _PulsePainter(this.t, this.color) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final v = Curves.easeOut.transform(t.value);
    final rect = (Offset.zero & size).inflate(10 * v);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(16 + 10 * v)),
      Paint()
        ..color = color.withValues(alpha: (1 - v) * 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.color != color;
}

/// Opens a dialog that springs up from slightly below instead of a plain fade.
Future<T?> showAppDialog<T>({required BuildContext context, required WidgetBuilder builder}) {
  final reduced = Motion.reduced(context);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Theme.of(context).colorScheme.scrim.withAlpha(120),
    transitionDuration: reduced ? Duration.zero : const Duration(milliseconds: 340),
    pageBuilder: (ctx, _, __) => Builder(builder: builder),
    transitionBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: Motion.overshoot, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.5, curve: Curves.easeOut)),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
