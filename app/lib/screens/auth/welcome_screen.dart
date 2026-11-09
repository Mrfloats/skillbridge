import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  /// How long each slide stays before the next one slides in.
  static const autoAdvanceEvery = Duration(seconds: 4);
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _page = PageController();
  int _index = 0;
  Timer? _auto;

  static const _slides = [
    (null, 'Find trusted help nearby', 'Plumbers, electricians, carpenters and more, all ID-verified and rated by real clients.'),
    (Icons.event_available_rounded, 'Book in a few taps', 'Pick a time, get a quote and track your job from request to done.'),
    (Icons.shield_rounded, 'Agree, then pay', 'Accept a quote in the app, then pay your provider directly. SOS help is one tap away.'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startAuto();
  }

  /// Advances the slides on a timer, unless the device asks for reduced motion.
  void _startAuto() {
    _auto?.cancel();
    if (Motion.reduced(context)) return;
    _auto = Timer.periodic(WelcomeScreen.autoAdvanceEvery, (_) {
      // Skip while another screen covers this one, or before the PageView is laid out.
      if (!mounted || !TickerMode.valuesOf(context).enabled || !_page.hasClients) return;
      _page.nextPage(duration: const Duration(milliseconds: 700), curve: Motion.emphasized);
    });
  }

  /// Pauses the timer while the user swipes, and restarts it when they let go.
  bool _onScroll(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _auto?.cancel();
    } else if (n is ScrollEndNotification && !(_auto?.isActive ?? false)) {
      _startAuto();
    }
    return false;
  }

  @override
  void dispose() {
    _auto?.cancel();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final palette = context.palette;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: palette.heroStart,
        body: Aurora(
          animate: true,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: Column(children: [
                Reveal(
                  child: const Align(alignment: Alignment.centerLeft, child: BrandLogo(height: 52)),
                ),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    // No item count, so the slides loop round forever.
                    child: PageView.builder(
                      controller: _page,
                      onPageChanged: (i) => setState(() => _index = i % _slides.length),
                      itemBuilder: (_, i) {
                        final (icon, title, body) = _slides[i % _slides.length];
                        return AnimatedBuilder(
                          animation: _page,
                          builder: (context, _) {
                            final page = _page.hasClients && _page.position.haveDimensions ? (_page.page ?? 0) : 0.0;
                            final offset = (page - i).clamp(-1.0, 1.0);
                            return Opacity(
                              opacity: 1 - offset.abs() * 0.75,
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                // The icon drifts at a different speed to the text for a parallax feel.
                                Transform.translate(
                                  offset: Offset(offset * 90, 0),
                                  child: Transform.scale(scale: 1 - offset.abs() * 0.2, child: icon == null ? const _FloatingLogo() : _SlideIcon(icon: icon)),
                                ),
                                const SizedBox(height: 40),
                                Text(title, style: t.displaySmall?.copyWith(color: Colors.white), textAlign: TextAlign.center),
                                const SizedBox(height: 14),
                                Text(body, style: t.bodyLarge?.copyWith(color: Colors.white.withAlpha(205)), textAlign: TextAlign.center),
                              ]),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < _slides.length; i++)
                    AnimatedContainer(
                      duration: Motion.medium,
                      curve: Motion.emphasized,
                      margin: const EdgeInsets.all(4),
                      width: i == _index ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index ? palette.accent : Colors.white.withAlpha(70),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ]),
                const SizedBox(height: 24),
                Reveal(
                  index: 2,
                  child: GlowButton(
                    label: 'Create an account',
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  ),
                ),
                const SizedBox(height: 12),
                Reveal(
                  index: 3,
                  child: OutlinedButton(
                    style: ButtonStyle(
                      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(54)),
                      foregroundColor: const WidgetStatePropertyAll(Colors.white),
                      overlayColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.pressed) || s.contains(WidgetState.hovered) ? Colors.white.withAlpha(30) : null),
                      side: WidgetStateProperty.resolveWith(
                          (s) => BorderSide(color: Colors.white.withAlpha(s.contains(WidgetState.hovered) ? 255 : 110), width: s.contains(WidgetState.hovered) ? 1.5 : 1)),
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                    child: const Text('I already have an account'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 3D S, floating gently on the first slide.
class _FloatingLogo extends StatefulWidget {
  const _FloatingLogo();
  @override
  State<_FloatingLogo> createState() => _FloatingLogoState();
}

class _FloatingLogoState extends State<_FloatingLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Transform.translate(offset: Offset(0, 6 - 12 * Curves.easeInOut.transform(_c.value)), child: child),
          child: Image.asset('assets/brand/logo_3d_s.png', width: 152, height: 177, cacheWidth: (152 * MediaQuery.devicePixelRatioOf(context)).ceil(), excludeFromSemantics: true),
        ),
      );
}

class _SlideIcon extends StatelessWidget {
  final IconData icon;
  const _SlideIcon({required this.icon});
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 156,
      height: 156,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withAlpha(16),
        border: Border.all(color: Colors.white.withAlpha(36)),
        boxShadow: [BoxShadow(color: palette.accent.withAlpha(60), blurRadius: 70, spreadRadius: 4)],
      ),
      alignment: Alignment.center,
      child: Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: palette.accentGradient),
        child: Icon(icon, size: 52, color: palette.onAccent),
      ),
    );
  }
}
