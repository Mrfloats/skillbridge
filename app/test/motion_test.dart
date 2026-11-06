import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge/core/theme.dart';
import 'package:skillbridge/widgets/motion.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: Center(child: child))),
    );

double _liftOf(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(find.descendant(of: find.byType(HoverCard), matching: find.byType(AnimatedContainer)));
  return container.transform!.getTranslation().y;
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await tester.pump();
  return mouse;
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('HoverCard', () {
    testWidgets('a mouse lifts it, tracks the spotlight, and leaving resets it', (tester) async {
      await tester.pumpWidget(_app(SizedBox(width: 200, height: 100, child: HoverCard(onTap: () {}, child: const Text('Card')))));
      final state = tester.state<HoverCardState>(find.byType(HoverCard));
      expect(state.isHovered, isFalse);
      expect(_liftOf(tester), 0);

      final mouse = await _mouse(tester);
      final center = tester.getCenter(find.byType(HoverCard));
      await mouse.moveTo(center);
      await tester.pump();
      expect(state.isHovered, isTrue);
      expect(_liftOf(tester), -4);
      expect(state.spotlightPosition, isNotNull);

      await mouse.moveTo(center + const Offset(30, 10));
      await tester.pump();
      expect(state.spotlightPosition!.dx, closeTo(130, 0.5));

      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(state.isHovered, isFalse);
      expect(_liftOf(tester), 0);
      expect(state.spotlightPosition, isNull);
    });

    testWidgets('shows the click cursor only when it can be tapped', (tester) async {
      await tester.pumpWidget(_app(SizedBox(width: 200, height: 100, child: HoverCard(onTap: () {}, child: const Text('Card')))));
      final region = tester.widget<MouseRegion>(find.descendant(of: find.byType(HoverCard), matching: find.byType(MouseRegion)).first);
      expect(region.cursor, SystemMouseCursors.click);
    });

    testWidgets('a card with no action ignores the mouse unless made hoverable', (tester) async {
      await tester.pumpWidget(_app(const SizedBox(width: 200, height: 100, child: HoverCard(child: Text('Card')))));
      final state = tester.state<HoverCardState>(find.byType(HoverCard));
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byType(HoverCard)));
      await tester.pump();
      expect(state.isHovered, isFalse);
      expect(_liftOf(tester), 0);
    });

    testWidgets('a touch press does not count as hovering, and still taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(SizedBox(width: 200, height: 100, child: HoverCard(onTap: () => taps++, child: const Text('Card')))));
      final state = tester.state<HoverCardState>(find.byType(HoverCard));
      final touch = await tester.startGesture(tester.getCenter(find.byType(HoverCard)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(state.isHovered, isFalse);
      await touch.up();
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 1);
    });

    testWidgets('reduced motion keeps the highlight but does not move the card', (tester) async {
      await tester.pumpWidget(_app(SizedBox(width: 200, height: 100, child: HoverCard(onTap: () {}, child: const Text('Card'))), reduceMotion: true));
      final state = tester.state<HoverCardState>(find.byType(HoverCard));
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byType(HoverCard)));
      await tester.pump();
      expect(state.isHovered, isTrue);
      expect(_liftOf(tester), 0);
    });
  });

  group('GlowButton', () {
    testWidgets('hovering runs the sheen once and tapping fires the action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(SizedBox(width: 240, child: GlowButton(label: 'Go', onPressed: () => taps++))));
      final state = tester.state<GlowButtonState>(find.byType(GlowButton));
      expect(state.isSheenRunning, isFalse);
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byType(GlowButton)));
      await tester.pump();
      expect(state.isSheenRunning, isTrue);
      await tester.pump(const Duration(seconds: 1));
      expect(state.isSheenRunning, isFalse);
      await tester.tap(find.byType(GlowButton));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 1);
    });

    testWidgets('while busy it shows a spinner and ignores taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(SizedBox(width: 240, child: GlowButton(label: 'Go', busy: true, onPressed: () => taps++))));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Go'), findsNothing);
      await tester.tap(find.byType(GlowButton));
      await tester.pump(const Duration(milliseconds: 400));
      expect(taps, 0);
    });
  });

  group('Motion widgets', () {
    testWidgets('Reveal ends fully visible', (tester) async {
      await tester.pumpWidget(_app(const Reveal(index: 2, child: Text('Hello'))));
      expect(tester.widget<Opacity>(find.ancestor(of: find.text('Hello'), matching: find.byType(Opacity))).opacity, 0);
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(find.ancestor(of: find.text('Hello'), matching: find.byType(Opacity))).opacity, 1);
    });

    testWidgets('Reveal skips the animation under reduced motion', (tester) async {
      await tester.pumpWidget(_app(const Reveal(child: Text('Hello')), reduceMotion: true));
      expect(tester.widget<Opacity>(find.ancestor(of: find.text('Hello'), matching: find.byType(Opacity))).opacity, 1);
    });

    testWidgets('CountUp settles on the exact value', (tester) async {
      await tester.pumpWidget(_app(CountUp(value: 1234, format: (v) => v.round().toString())));
      await tester.pumpAndSettle();
      expect(find.text('1234'), findsOneWidget);
    });

    testWidgets('FadeIndexedStack keeps the state of hidden pages', (tester) async {
      Widget stack(int index) => _app(SizedBox(
            width: 300,
            height: 300,
            child: FadeIndexedStack(index: index, children: const [_Counter(key: ValueKey('a')), Text('Other page')]),
          ));
      await tester.pumpWidget(stack(0));
      await tester.tap(find.byKey(const ValueKey('counter-button')));
      await tester.pump();
      expect(find.text('count 1'), findsOneWidget);

      await tester.pumpWidget(stack(1));
      await tester.pumpAndSettle();
      expect(find.text('count 1'), findsNothing);
      expect(find.text('Other page'), findsOneWidget);

      await tester.pumpWidget(stack(0));
      await tester.pumpAndSettle();
      expect(find.text('count 1'), findsOneWidget);
    });
  });

  group('Palette', () {
    test('text pairs meet WCAG AA contrast in both themes', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final c = theme.colorScheme;
        final p = theme.extension<AppPalette>()!;
        final pairs = <String, (Color, Color)>{
          'primary': (c.onPrimary, c.primary),
          'secondary': (c.onSecondary, c.secondary),
          'error': (c.onError, c.error),
          'surface': (c.onSurface, c.surface),
          'surface variant': (c.onSurfaceVariant, c.surface),
          'card variant': (c.onSurfaceVariant, c.surfaceContainerLowest),
          'primary container': (c.onPrimaryContainer, c.primaryContainer),
          'secondary container': (c.onSecondaryContainer, c.secondaryContainer),
          'tertiary container': (c.onTertiaryContainer, c.tertiaryContainer),
          'error container': (c.onErrorContainer, c.errorContainer),
          'accent': (p.onAccent, p.accent),
          'white on hero start': (Colors.white, p.heroStart),
          'white on hero end': (Colors.white, p.heroEnd),
          'success on card': (p.success, c.surfaceContainerLowest),
          'warning on card': (p.warning, c.surfaceContainerLowest),
        };
        pairs.forEach((name, pair) {
          expect(_contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5), reason: '$name in ${c.brightness}');
        });
      }
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _n = 0;
  @override
  Widget build(BuildContext context) => TextButton(
        key: const ValueKey('counter-button'),
        onPressed: () => setState(() => _n++),
        child: Text('count $_n'),
      );
}
