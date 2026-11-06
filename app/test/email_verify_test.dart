import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge/core/theme.dart';
import 'package:skillbridge/models/models.dart';
import 'package:skillbridge/screens/auth/email_verify_screen.dart';

final _user = AppUser(uid: 'u', fullName: 'Test User', email: 'user@example.com', phone: '', role: 'client');

Future<void> _pump(
  WidgetTester tester, {
  required Future<bool> Function() check,
  Future<void> Function()? resend,
  VoidCallback? onVerified,
  VoidCallback? onUsePhone,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: EmailVerifyScreen(user: _user, onVerified: onVerified ?? () {}, onUsePhone: onUsePhone ?? () {}, check: check, resend: resend ?? () async {}),
  ));
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('shows which address the link went to', (tester) async {
    await _pump(tester, check: () async => false);
    expect(find.textContaining('user@example.com'), findsOneWidget);
  });

  testWidgets('the button says so when the email is not verified yet', (tester) async {
    var verified = 0;
    await _pump(tester, check: () async => false, onVerified: () => verified++);
    await tester.tap(find.text('I have verified'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Not verified yet'), findsOneWidget);
    expect(verified, 0);
  });

  testWidgets('the button moves on once the email is verified', (tester) async {
    var verified = 0;
    await _pump(tester, check: () async => true, onVerified: () => verified++);
    await tester.tap(find.text('I have verified'));
    await tester.pump();
    await tester.pump();
    expect(verified, 1);
  });

  testWidgets('coming back from the email app rechecks without an error message', (tester) async {
    var checks = 0, verified = 0;
    await _pump(tester, check: () async => ++checks > 1, onVerified: () => verified++);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(checks, 1);
    expect(find.textContaining('Not verified yet'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(verified, 1);
  });

  testWidgets('offers a text message instead', (tester) async {
    var chosen = 0;
    await _pump(tester, check: () async => false, onUsePhone: () => chosen++);
    await tester.tap(find.text('Use a text message instead'));
    expect(chosen, 1);
  });

  testWidgets('resending confirms the address', (tester) async {
    var sent = 0;
    await _pump(tester, check: () async => false, resend: () async => sent++);
    await tester.tap(find.text('Resend email'));
    await tester.pump();
    await tester.pump();
    expect(sent, 1);
    expect(find.text('Email sent to user@example.com'), findsOneWidget);
  });
}
