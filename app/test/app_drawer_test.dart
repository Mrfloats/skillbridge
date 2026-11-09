import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge/core/theme.dart';
import 'package:skillbridge/models/models.dart';
import 'package:skillbridge/widgets/app_drawer.dart';

final _user = AppUser(uid: 'u', fullName: 'Obey Moyo', email: 'o@example.com', phone: '+263771234567', role: 'provider');

const _items = [
  AppNavItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard_rounded, label: 'Dashboard'),
  AppNavItem(icon: Icons.work_outline_rounded, selectedIcon: Icons.work_rounded, label: 'Jobs'),
  AppNavItem(icon: Icons.account_balance_wallet_outlined, selectedIcon: Icons.account_balance_wallet_rounded, label: 'Wallet'),
];

/// A small stand-in for a shell: the menu, plus a page with a menu button that shows the open section.
class _Shell extends StatefulWidget {
  final Stream<RatingSummary?> Function()? rating;
  const _Shell({this.rating});
  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  final _scaffold = GlobalKey<ScaffoldState>();
  int tab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        key: _scaffold,
        drawer: AppDrawer(
          user: _user,
          items: _items,
          index: tab,
          rating: widget.rating,
          onChanged: (i) => setState(() => tab = i),
          onProfile: () => setState(() => tab = 3),
        ),
        body: ShellMenu(
          open: () => _scaffold.currentState?.openDrawer(),
          child: Builder(builder: (context) => Scaffold(appBar: AppBar(leading: ShellMenu.button(context), title: Text('Section $tab')))),
        ),
      );
}

Future<void> _openMenu(WidgetTester tester, {Stream<RatingSummary?> Function()? rating}) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: _Shell(rating: rating)));
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the menu shows the user\'s name and rating at the top', (tester) async {
    await _openMenu(tester, rating: () => Stream.value((average: 4.86, count: 15)));
    expect(find.text('Obey Moyo'), findsOneWidget);
    expect(find.text('4.9 (15)'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
    expect(find.byIcon(Icons.star_half_rounded), findsOneWidget);
  });

  testWidgets('a user with no reviews sees "No ratings yet"', (tester) async {
    await _openMenu(tester, rating: () => Stream.value((average: 0, count: 0)));
    expect(find.text('No ratings yet'), findsOneWidget);
  });

  testWidgets('a client who has never been rated also sees "No ratings yet"', (tester) async {
    // A client's rating document does not exist until their first rating.
    await _openMenu(tester, rating: () => Stream<RatingSummary?>.value(null));
    expect(find.text('No ratings yet'), findsOneWidget);
  });

  testWidgets('a user who is not rated sees a link to their profile', (tester) async {
    await _openMenu(tester);
    expect(find.text('View profile'), findsOneWidget);
  });

  testWidgets('tapping a section closes the menu and opens it', (tester) async {
    await _openMenu(tester);
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    expect(find.text('Section 2'), findsOneWidget);
    expect(find.text('Wallet'), findsNothing);
  });

  testWidgets('tapping the top of the menu opens the profile', (tester) async {
    await _openMenu(tester);
    await tester.tap(find.text('Obey Moyo'));
    await tester.pumpAndSettle();
    expect(find.text('Section 3'), findsOneWidget);
  });

  testWidgets('links under the sections open their page, and show a count when there is one', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          drawer: AppDrawer(user: _user, items: _items, index: 0, onChanged: (_) {}, onProfile: () {}, links: [
            AppDrawerLink(icon: Icons.settings_outlined, label: 'Settings', onTap: () => opened.add('Settings')),
            AppDrawerLink(icon: Icons.notifications_outlined, label: 'Notifications', onTap: () => opened.add('Notifications'), count: () => Stream.value(3)),
            AppDrawerLink(icon: Icons.help_outline_rounded, label: 'Help', onTap: () => opened.add('Help'), count: () => Stream.value(0)),
          ]),
          body: const SizedBox.expand(),
        ),
      ),
    ));
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget, reason: 'unread count');
    expect(find.text('0'), findsNothing, reason: 'no badge when there is nothing new');

    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(opened, ['Notifications']);
    expect(find.text('Settings'), findsNothing, reason: 'the menu closed');
  });

  testWidgets('the mode button sits at the bottom of the menu and closes it when tapped', (tester) async {
    var switched = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        drawer: AppDrawer(
          user: _user,
          items: _items,
          index: 0,
          onChanged: (_) {},
          onProfile: () {},
          modeSwitch: AppDrawerLink(icon: Icons.handyman_rounded, label: 'Provider mode', onTap: () => switched = true),
        ),
        body: const SizedBox.expand(),
      ),
    ));
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
    final button = tester.getRect(find.text('Provider mode'));
    expect(button.top, greaterThan(tester.getRect(find.text('Wallet')).bottom), reason: 'below the sections');

    await tester.tap(find.text('Provider mode'));
    await tester.pumpAndSettle();
    expect(switched, isTrue);
    expect(find.text('Provider mode'), findsNothing, reason: 'the menu closed');
  });

  testWidgets('pages outside a shell keep their back button', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) => Scaffold(body: Text(ShellMenu.button(context) == null ? 'no menu' : 'menu'))),
    ));
    expect(find.text('no menu'), findsOneWidget);
  });
}
