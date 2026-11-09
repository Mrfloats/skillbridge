import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge/core/theme.dart';
import 'package:skillbridge/screens/auth/welcome_screen.dart';

const _first = 'Find trusted help nearby';
const _second = 'Book in a few taps';
const _third = 'Agree, then pay';

// The background animates forever, so the tests pump fixed times instead of pumpAndSettle.
Future<void> _pump(WidgetTester tester, {bool reduceMotion = false}) async {
  // A typical phone screen (the test default is a short landscape window).
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: MediaQuery(data: MediaQueryData(disableAnimations: reduceMotion), child: const WelcomeScreen()),
  ));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Waits one auto-advance interval, then lets the slide animation finish.
Future<void> _waitOneSlide(WidgetTester tester) async {
  await tester.pump(WelcomeScreen.autoAdvanceEvery);
  await tester.pump(const Duration(seconds: 1));
}

bool _showing(String title) => find.text(title).hitTestable().evaluate().isNotEmpty;

void main() {
  testWidgets('slides move on their own and loop back to the start', (tester) async {
    await _pump(tester);
    expect(_showing(_first), isTrue);

    await _waitOneSlide(tester);
    expect(_showing(_second), isTrue);

    await _waitOneSlide(tester);
    expect(_showing(_third), isTrue);

    await _waitOneSlide(tester);
    expect(_showing(_first), isTrue);
  });

  testWidgets('holding a swipe pauses the slides', (tester) async {
    await _pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text(_first)));
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump(WelcomeScreen.autoAdvanceEvery * 2);
    await gesture.moveBy(const Offset(20, 0));
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    expect(_showing(_first), isTrue);

    // Once released, the timer starts again.
    await _waitOneSlide(tester);
    expect(_showing(_second), isTrue);
  });

  testWidgets('slides stay put when the phone has animations turned off', (tester) async {
    await _pump(tester, reduceMotion: true);
    await _waitOneSlide(tester);
    await _waitOneSlide(tester);
    expect(_showing(_first), isTrue);
  });
}
