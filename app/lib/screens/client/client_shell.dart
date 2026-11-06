import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../widgets/app_nav_bar.dart';
import '../../widgets/motion.dart';
import '../shared/bookings_list_screen.dart';
import '../shared/profile_screen.dart';
import '../shared/wallet_screen.dart';
import 'client_home_screen.dart';

class ClientShell extends StatefulWidget {
  final AppUser user;
  const ClientShell({super.key, required this.user});
  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ClientHomeScreen(user: widget.user),
      BookingsListScreen(user: widget.user, asProvider: false),
      WalletScreen(user: widget.user),
      ProfileScreen(user: widget.user),
    ];
    return Scaffold(
      body: FadeIndexedStack(index: _tab, children: pages),
      bottomNavigationBar: AppNavBar(
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
        items: const [
          AppNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
          AppNavItem(icon: Icons.event_note_outlined, selectedIcon: Icons.event_note_rounded, label: 'Bookings'),
          AppNavItem(icon: Icons.account_balance_wallet_outlined, selectedIcon: Icons.account_balance_wallet_rounded, label: 'Wallet'),
          AppNavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
        ],
      ),
    );
  }
}
