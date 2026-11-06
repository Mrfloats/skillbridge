import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../widgets/app_nav_bar.dart';
import '../../widgets/motion.dart';
import '../shared/bookings_list_screen.dart';
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
  int _tab = 0;

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
      body: FadeIndexedStack(index: _tab, children: pages),
      bottomNavigationBar: AppNavBar(
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
        items: const [
          AppNavItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard_rounded, label: 'Dashboard'),
          AppNavItem(icon: Icons.work_outline_rounded, selectedIcon: Icons.work_rounded, label: 'Jobs'),
          AppNavItem(icon: Icons.account_balance_wallet_outlined, selectedIcon: Icons.account_balance_wallet_rounded, label: 'Wallet'),
          AppNavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
        ],
      ),
    );
  }
}
