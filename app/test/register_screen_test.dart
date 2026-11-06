import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge/core/theme.dart';
import 'package:skillbridge/screens/auth/register_screen.dart';

const _mismatch = 'Passwords do not match';
const _termsPrompt = 'Please accept the terms and privacy policy.';

Future<void> _fillAndSubmit(WidgetTester tester, {required String password, required String confirm}) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: const RegisterScreen()));
  await tester.pump(const Duration(seconds: 2));

  Future<void> enter(String label, String value) => tester.enterText(find.widgetWithText(TextFormField, label), value);
  await enter('Full name', 'Test User');
  await enter('Email', 'user@example.com');
  await enter('Mobile number', '0771234567');
  await enter('Password', password);
  await enter('Confirm password', confirm);

  final signUp = find.text('Sign up');
  await tester.ensureVisible(signUp);
  await tester.pump(const Duration(seconds: 1));
  await tester.tap(signUp);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('different passwords are rejected', (tester) async {
    await _fillAndSubmit(tester, password: 'correct-horse', confirm: 'correct-horsf');
    expect(find.text(_mismatch), findsOneWidget);
    expect(find.text(_termsPrompt), findsNothing);
  });

  testWidgets('an empty confirmation is rejected', (tester) async {
    await _fillAndSubmit(tester, password: 'correct-horse', confirm: '');
    expect(find.text(_mismatch), findsOneWidget);
    expect(find.text(_termsPrompt), findsNothing);
  });

  // The terms checkbox is left unticked, so a form that passes validation stops
  // at the terms prompt, before anything reaches Firebase.
  testWidgets('matching passwords pass validation', (tester) async {
    await _fillAndSubmit(tester, password: 'correct-horse', confirm: 'correct-horse');
    expect(find.text(_mismatch), findsNothing);
    expect(find.text(_termsPrompt), findsOneWidget);
  });
}
