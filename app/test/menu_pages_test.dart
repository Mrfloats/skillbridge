import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skillbridge/core/legal.dart';
import 'package:skillbridge/core/theme.dart';
import 'package:skillbridge/models/models.dart';
import 'package:skillbridge/screens/shared/help_screen.dart';
import 'package:skillbridge/screens/shared/settings_screen.dart';
import 'package:skillbridge/screens/shared/support_screen.dart';
import 'package:skillbridge/services/settings_service.dart';

AppUser _user(String role) => AppUser(uid: 'u', fullName: 'Test User', email: 'u@example.com', phone: '+263771234567', role: role);

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: page));
  await tester.pumpAndSettle();
}

void main() {
  group('appearance', () {
    test('is saved on the phone and read back at startup', () async {
      SharedPreferences.setMockInitialValues({});
      await AppSettings.instance.load();
      expect(AppSettings.instance.themeMode.value, ThemeMode.system);

      await AppSettings.instance.setThemeMode(ThemeMode.dark);
      AppSettings.instance.themeMode.value = ThemeMode.light; // as if the app restarted
      await AppSettings.instance.load();
      expect(AppSettings.instance.themeMode.value, ThemeMode.dark);
    });

    test('falls back to the phone setting when the saved value is unknown', () async {
      SharedPreferences.setMockInitialValues({'themeMode': 'purple'});
      await AppSettings.instance.load();
      expect(AppSettings.instance.themeMode.value, ThemeMode.system);
    });
  });

  group('help', () {
    testWidgets('providers get answers about the service charge, worked out from the real rate', (tester) async {
      await _pump(tester, HelpScreen(user: _user('provider')));
      expect(find.text('How do I book a provider?'), findsNothing);
      await tester.tap(find.text('How does the service charge work?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('charges 10% of each job'), findsOneWidget);
      expect(find.textContaining('a US\$50.00 job costs US\$5.00'), findsOneWidget);
    });

    testWidgets('clients get answers about booking and paying, and a way to contact support', (tester) async {
      var contacted = false;
      await _pump(tester, HelpScreen(user: _user('client'), onContactSupport: () => contacted = true));
      expect(find.text('How does the service charge work?'), findsNothing);
      await tester.tap(find.text('How do I pay?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('You pay the provider directly'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Contact support'), 300);
      await tester.tap(find.text('Contact support'));
      expect(contacted, isTrue);
    });
  });

  testWidgets('legal documents show every section', (tester) async {
    await _pump(tester, const LegalScreen(title: 'Privacy Policy', sections: privacyPolicy));
    expect(find.text('Last updated $legalUpdated'), findsOneWidget);
    for (final (heading, _) in privacyPolicy.take(2)) {
      expect(find.text(heading), findsOneWidget);
    }
  });

  group('support', () {
    testWidgets('asks for a topic and enough detail before sending', (tester) async {
      await _pump(tester, SupportScreen(user: _user('client'), tickets: () => Stream.value(const [])));
      await tester.tap(find.text('Send message'));
      await tester.pump();
      expect(find.text('Choose a topic'), findsOneWidget);
      expect(find.text('Tell us a little more'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).last, 'help');
      await tester.tap(find.text('Send message'));
      await tester.pump();
      expect(find.text('Tell us a little more'), findsOneWidget);
    });

    testWidgets('lists past messages with their status and any reply', (tester) async {
      final tickets = [
        SupportTicket('1', 'u', 'Test User', '', '', 'client', 'payment', 'I was charged twice', 'resolved', 'Refunded by the provider', DateTime(2026, 11, 2)),
        SupportTicket('2', 'u', 'Test User', '', '', 'client', 'other', 'How do I change my email?', 'open', '', DateTime(2026, 11, 8)),
      ];
      await _pump(tester, SupportScreen(user: _user('client'), tickets: () => Stream.value(tickets)));
      expect(find.text('Your messages'), findsOneWidget);
      expect(find.text('Payments or my balance'), findsOneWidget);
      expect(find.textContaining('Reply: Refunded by the provider'), findsOneWidget);
      expect(find.text('Closed'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
    });
  });
}
