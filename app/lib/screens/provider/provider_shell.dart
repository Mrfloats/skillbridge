import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/db.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/motion.dart';
import '../shared/bookings_list_screen.dart';
import '../shared/drawer_links.dart';
import '../shared/profile_screen.dart';
import '../shared/wallet_screen.dart';
import 'provider_dashboard_screen.dart';
import 'provider_setup_screen.dart';
import 'verification_screen.dart';

class ProviderShell extends StatefulWidget {
  final AppUser user;
  const ProviderShell({super.key, required this.user});
  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  final _scaffold = GlobalKey<ScaffoldState>();
  int _tab = 0;

  /// The profile is opened from the top of the side menu, so it has no menu item of its own.
  static const _profileTab = 3;

  Stream<RatingSummary?> _rating() => Db.instance.provider(widget.user.uid).map((p) => p == null ? null : (average: p.avgRating, count: p.reviewCount));

  @override
  Widget build(BuildContext context) {
    final pages = [
      ProviderDashboardScreen(user: widget.user),
      BookingsListScreen(user: widget.user, asProvider: true),
      WalletScreen(user: widget.user),
      ProfileScreen(user: widget.user, extraTiles: [
        ListTile(
          leading: const Icon(Icons.storefront_outlined),
          title: const Text('Business profile & services'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderSetupScreen(user: widget.user))),
        ),
        ListTile(
          leading: const Icon(Icons.verified_user_outlined),
          title: const Text('ID verification'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VerificationScreen(user: widget.user))),
        ),
      ]),
    ];
    return Scaffold(
      key: _scaffold,
      drawer: AppDrawer(
        user: widget.user,
        rating: _rating,
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
        onProfile: () => setState(() => _tab = _profileTab),
        links: drawerLinks(context, widget.user),
        modeSwitch: modeSwitch(context, widget.user),
        items: const [
          AppNavItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard_rounded, label: 'Dashboard'),
          AppNavItem(icon: Icons.work_outline_rounded, selectedIcon: Icons.work_rounded, label: 'Jobs'),
          AppNavItem(icon: Icons.account_balance_wallet_outlined, selectedIcon: Icons.account_balance_wallet_rounded, label: 'Wallet'),
        ],
      ),
      body: ShellMenu(
        open: () => _scaffold.currentState?.openDrawer(),
        child: FadeIndexedStack(index: _tab, children: pages),
      ),
    );
  }
}
