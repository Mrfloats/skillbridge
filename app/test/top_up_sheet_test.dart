import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge/core/theme.dart';
import 'package:skillbridge/models/models.dart';
import 'package:skillbridge/screens/shared/wallet_screen.dart';

final _provider = AppUser(uid: 'p', fullName: 'Test Provider', email: 'p@example.com', phone: '+263771234567', role: 'provider');

Future<void> _pump(WidgetTester tester) => tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: TopUpSheet(user: _provider)),
    ));

void main() {
  testWidgets('starts with the provider\'s number in local format', (tester) async {
    await _pump(tester);
    final phone = tester.widget<TextField>(find.widgetWithText(TextField, 'Mobile money number'));
    expect(phone.controller!.text, '0771234567');
  });

  testWidgets('card payments do not ask for a number', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Card'));
    await tester.pumpAndSettle();
    expect(find.text('Mobile money number'), findsNothing);
  });

  // Rejected amounts stop before any call to the backend, which is not available here.
  for (final amount in ['0.50', '0', 'abc']) {
    testWidgets('rejects an amount of "$amount"', (tester) async {
      await _pump(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Amount (US\$)'), amount);
      await tester.tap(find.text('Pay with PayNow'));
      await tester.pump();
      expect(find.text('Enter at least US\$1.00'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
    });
  }
}
