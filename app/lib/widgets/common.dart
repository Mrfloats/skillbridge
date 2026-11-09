import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../services/device_services.dart';
import 'motion.dart';

export 'motion.dart';

void showSnack(BuildContext context, String message, {bool error = false}) {
  final c = Theme.of(context).colorScheme;
  final foreground = error ? c.onError : c.onInverseSurface;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: foreground, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: TextStyle(color: foreground, fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: error ? c.error : null,
      behavior: SnackBarBehavior.floating,
    ));
}

/// Runs [action], shows a friendly message on failure, and returns whether it succeeded.
Future<bool> runGuarded(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) showSnack(context, success);
    return true;
  } catch (e) {
    if (context.mounted) showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    return false;
  }
}

Future<bool> confirmDialog(BuildContext context, String title, String body, {String ok = 'Confirm', bool danger = false}) async {
  final r = await showAppDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error, foregroundColor: Theme.of(ctx).colorScheme.onError, minimumSize: const Size(88, 44))
              : FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r == true;
}

Future<String?> textPrompt(BuildContext context, String title, {String? message, String hint = '', String ok = 'Submit', int minLength = 0, TextInputType? keyboard}) {
  final ctrl = TextEditingController();
  return showAppDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (message != null) ...[Text(message), const SizedBox(height: 12)],
        TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: keyboard,
          maxLines: keyboard == null ? 3 : 1,
          decoration: InputDecoration(hintText: hint),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: () {
            if (ctrl.text.trim().length < minLength) return;
            Navigator.pop(ctx, ctrl.text.trim());
          },
          child: Text(ok),
        ),
      ],
    ),
  );
}

/// Status pill with a coloured dot. Its colour animates when the status changes.
class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final color = statusColor(status, Theme.of(context).colorScheme);
    return AnimatedContainer(
      duration: Motion.medium,
      curve: Motion.emphasized,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withAlpha(32), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: Motion.medium,
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(statusLabel(status), style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }
}

class RatingStars extends StatelessWidget {
  final double rating;
  final int? count;
  final double size;
  const RatingStars(this.rating, {super.key, this.count, this.size = 16});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          rating >= i ? Icons.star_rounded : (rating >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
          size: size,
          color: context.palette.star,
        ),
      const SizedBox(width: 4),
      Text(count == null ? rating.toStringAsFixed(1) : '${rating.toStringAsFixed(1)} ($count)', style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class VerifiedBadge extends StatelessWidget {
  final Color? color;
  const VerifiedBadge({super.key, this.color});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'ID verified by SkillBridge',
      child: Icon(Icons.verified_rounded, size: 18, color: color ?? (c.brightness == Brightness.dark ? c.primary : c.secondary)),
    );
  }
}

/// Photo, or initials on a gradient when there is no photo.
class Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;
  const Avatar({super.key, this.url, required this.name, this.radius = 24});
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final initials = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).take(2).map((s) => s[0].toUpperCase()).join();
    final hasPhoto = url != null && url!.isNotEmpty;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasPhoto ? null : palette.heroGradient,
        image: hasPhoto ? DecorationImage(image: StoredImage(url!), fit: BoxFit.cover) : null,
      ),
      alignment: Alignment.center,
      child: hasPhoto
          ? null
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                initials.isEmpty ? '?' : initials,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: palette.accent,
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: radius * 0.72,
                    ),
              ),
            ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Reveal(
            offset: const Offset(0, 10),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
              child: Icon(icon, size: 44, color: c.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: 18),
          Reveal(index: 1, child: Text(title, style: t.titleLarge, textAlign: TextAlign.center)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Reveal(index: 2, child: Text(message!, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant), textAlign: TextAlign.center)),
          ],
          if (action != null) ...[const SizedBox(height: 20), Reveal(index: 3, child: action!)],
        ]),
      ),
    );
  }
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

/// Branded holding screen, shown while the session and profile load.
class BrandSplash extends StatefulWidget {
  const BrandSplash({super.key});

  /// The logo plays its entrance once per launch, not again if a second loading stage follows.
  static bool _hasPlayed = false;

  @override
  State<BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<BrandSplash> {
  late final bool _animate;

  @override
  void initState() {
    super.initState();
    _animate = !BrandSplash._hasPlayed;
    BrandSplash._hasPlayed = true;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final t = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: palette.heroStart,
        body: Aurora(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              BrandMark(size: 104, animate: _animate),
              const SizedBox(height: 30),
              Image.asset(BrandLogo.wordmarkAsset, height: 46, excludeFromSemantics: true),
              const SizedBox(height: 6),
              Text(AppConfig.tagline, style: t.bodyMedium?.copyWith(color: Colors.white.withAlpha(205))),
              const SizedBox(height: 32),
              SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: palette.accent)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The 3D SkillBridge tile. [size] is the tile itself: its soft shadow spills
/// outside that box, so it lines up like a plain square. With [animate] it
/// settles into place with a small spring.
class BrandMark extends StatelessWidget {
  static const asset = 'assets/brand/logo_3d.png';

  final double size;
  final bool animate;
  const BrandMark({super.key, this.size = 44, this.animate = false});

  Widget _image(BuildContext context) {
    // Measured from the artwork: the tile fills 80% of the image and sits up and to the left.
    final width = size * 1.245;
    final height = width * 1651 / 1627;
    return SizedBox.square(
      dimension: size,
      child: OverflowBox(
        minWidth: width,
        maxWidth: width,
        minHeight: height,
        maxHeight: height,
        child: Transform.translate(
          offset: Offset(width * 0.0615, height * 0.041),
          child: Image.asset(asset, width: width, height: height, cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).ceil(), excludeFromSemantics: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!animate || Motion.reduced(context)) return _image(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      child: _image(context),
      builder: (context, progress, child) => Opacity(
        opacity: progress.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.7 + 0.3 * progress, child: child),
      ),
    );
  }
}

/// The full 3D logo for dark teal headers, in the proportions of the logo artwork.
/// [height] is the height of the tile, matching [BrandMark].
class BrandLogo extends StatelessWidget {
  static const lockupAsset = 'assets/brand/logo_3d_lockup_on_dark.png';
  static const wordmarkAsset = 'assets/brand/wordmark_on_dark.png';

  final double height;
  const BrandLogo({super.key, this.height = 40});

  @override
  Widget build(BuildContext context) {
    final imageHeight = height * 1.095;
    final imageWidth = imageHeight * 1519 / 520;
    return Semantics(
      image: true,
      label: AppConfig.appName,
      child: ExcludeSemantics(
        child: Image.asset(lockupAsset, width: imageWidth, height: imageHeight, cacheWidth: (imageWidth * MediaQuery.devicePixelRatioOf(context)).ceil()),
      ),
    );
  }
}

/// Curved teal header used at the top of the main screens.
class HeroPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const HeroPanel({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 28)});
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Aurora(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        child: SafeArea(bottom: false, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// A scrolling page topped by a [HeroPanel]. Strips fade in behind the status bar as
/// the page scrolls, so header text never runs under the clock and the icons stay readable.
class HeroScrollView extends StatefulWidget {
  final Widget hero;
  final List<Widget> children;
  const HeroScrollView({super.key, required this.hero, required this.children});

  @override
  State<HeroScrollView> createState() => _HeroScrollViewState();
}

class _HeroScrollViewState extends State<HeroScrollView> {
  final _heroKey = GlobalKey();
  double? _heroHeight;
  final _scrolled = ValueNotifier(false);
  final _pastHero = ValueNotifier(false);

  @override
  void dispose() {
    _scrolled.dispose();
    _pastHero.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    _scrolled.value = n.metrics.pixels > 1;
    // The list disposes the header once it is far off screen, so keep its last measured height.
    final box = _heroKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) _heroHeight = box.size.height;
    final height = _heroHeight;
    if (height != null) _pastHero.value = n.metrics.pixels > height - MediaQuery.paddingOf(context).top;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final surfaceStyle = theme.brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    Widget strip(ValueNotifier<bool> shown, Decoration decoration) => ValueListenableBuilder<bool>(
          valueListenable: shown,
          builder: (context, on, _) => AnimatedOpacity(
            opacity: on ? 1 : 0,
            duration: Motion.fast,
            child: DecoratedBox(decoration: decoration),
          ),
        );
    return ValueListenableBuilder<bool>(
      valueListenable: _pastHero,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ListView(padding: EdgeInsets.zero, children: [
          KeyedSubtree(key: _heroKey, child: widget.hero),
          ...widget.children,
        ]),
      ),
      builder: (context, past, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: past ? surfaceStyle : SystemUiOverlayStyle.light,
        child: Stack(fit: StackFit.expand, children: [
          child!,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).top,
            child: IgnorePointer(
              child: Stack(fit: StackFit.expand, children: [
                strip(_scrolled, BoxDecoration(gradient: LinearGradient(colors: [palette.heroStart, Color.lerp(palette.heroStart, palette.heroEnd, 0.5)!]))),
                strip(_pastHero, BoxDecoration(color: theme.colorScheme.surface)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Maps Firestore category icon names to Material icons.
IconData categoryIcon(String name) => switch (name) {
      'plumbing' => Icons.plumbing_rounded,
      'electrical_services' => Icons.electrical_services_rounded,
      'carpenter' => Icons.carpenter_rounded,
      'format_paint' => Icons.format_paint_rounded,
      'yard' => Icons.yard_rounded,
      'cleaning_services' => Icons.cleaning_services_rounded,
      'construction' => Icons.construction_rounded,
      'hardware' => Icons.hardware_rounded,
      'solar_power' => Icons.solar_power_rounded,
      _ => Icons.build_rounded,
    };
