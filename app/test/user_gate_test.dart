import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge/core/theme.dart';
import 'package:skillbridge/main.dart';
import 'package:skillbridge/models/models.dart';
import 'package:skillbridge/widgets/common.dart';

const _problem = 'We could not load your account';

Future<void> _pumpGate(WidgetTester tester, Stream<AppUser?> Function() load) =>
    tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: UserGate(uid: 'u', load: load)));

void main() {
  test('a verified email or phone is enough, and admins skip verification', () {
    AppUser user(String role, {bool phoneVerified = false}) =>
        AppUser(uid: 'u', fullName: 'T', email: 'e', phone: 'p', role: role, phoneVerified: phoneVerified);
    expect(mustVerify(user('client'), emailVerified: false), isTrue);
    expect(mustVerify(user('client'), emailVerified: true), isFalse);
    expect(mustVerify(user('provider', phoneVerified: true), emailVerified: false), isFalse);
    expect(mustVerify(user('admin'), emailVerified: false), isFalse);
  });

  testWidgets('a refused profile shows a way out instead of loading forever', (tester) async {
    var loads = 0;
    await _pumpGate(tester, () {
      loads++;
      return Stream<AppUser?>.error(Exception('permission-denied'));
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(_problem), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(loads, 2);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a missing profile waits, then shows a way out', (tester) async {
    await _pumpGate(tester, () => Stream<AppUser?>.value(null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 19));
    expect(find.byType(BrandSplash), findsOneWidget);
    expect(find.text(_problem), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(_problem), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
