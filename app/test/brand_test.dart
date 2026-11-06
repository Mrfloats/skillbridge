import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge/core/theme.dart';
import 'package:skillbridge/widgets/common.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: Center(child: child))),
    );

void main() {
  testWidgets('the logo is announced once, by name, and its assets load', (tester) async {
    await tester.pumpWidget(_app(const BrandLogo(height: 40)));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('SkillBridge'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final bundle = DefaultAssetBundle.of(tester.element(find.byType(BrandLogo)));
    for (final asset in [BrandLogo.lockupAsset, BrandLogo.wordmarkAsset, BrandMark.asset, 'assets/brand/logo_3d_s.png']) {
      await expectLater(bundle.load(asset), completes);
    }
  });

  testWidgets('the animated mark plays its entrance and keeps its size', (tester) async {
    await tester.pumpWidget(_app(const BrandMark(size: 96, animate: true)));
    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(BrandMark)), const Size.square(96));
  });

  testWidgets('reduced motion shows the finished mark straight away', (tester) async {
    await tester.pumpWidget(_app(const BrandMark(size: 96, animate: true), reduceMotion: true));
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });

  testWidgets('the splash shows the tagline and only animates on its first appearance', (tester) async {
    await tester.pumpWidget(_app(const SizedBox(width: 400, height: 700, child: BrandSplash())));
    expect(find.text('Trusted help, close to home'), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));

    await tester.pumpWidget(_app(const SizedBox(width: 400, height: 700, child: BrandSplash(key: ValueKey('second')))));
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });

  testWidgets('status bar strips cover header text while scrolling, then match the page', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(400, 800), padding: EdgeInsets.only(top: 24)),
        child: Scaffold(
          body: HeroScrollView(
            hero: const SizedBox(height: 200, child: Text('Header')),
            children: [for (var i = 0; i < 30; i++) SizedBox(height: 100, child: Text('Row '))],
          ),
        ),
      ),
    ));
    List<double> strips() => tester.widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity)).map((o) => o.opacity).toList();
    expect(strips(), [0, 0]);

    await tester.drag(find.byType(ListView), const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(strips(), [1, 0]);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(strips(), [1, 1]);

    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pumpAndSettle();
    expect(strips(), [0, 0]);
  });
}
