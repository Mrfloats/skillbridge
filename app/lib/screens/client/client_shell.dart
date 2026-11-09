import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/db.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/motion.dart';
import '../shared/bookings_list_screen.dart';
import '../shared/drawer_links.dart';
import '../shared/profile_screen.dart';
import 'client_home_screen.dart';

class ClientShell extends StatefulWidget {
  final AppUser user;
  const ClientShell({super.key, required this.user});
  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  final _scaffold = GlobalKey<ScaffoldState>();
  int _tab = 0;

  /// The profile is opened from the top of the side menu, so it has no menu item of its own.
  static const _profileTab = 2;

  @override
  Widget build(BuildContext context) {
    // Clients pay providers directly, so they have no wallet.
    final pages = [
      ClientHomeScreen(user: widget.user),
      BookingsListScreen(user: widget.user, asProvider: false),
      ProfileScreen(user: widget.user),
    ];
    return Scaffold(
      key: _scaffold,
      drawer: AppDrawer(
        user: widget.user,
        rating: () => Db.instance.clientRating(widget.user.uid),
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
        onProfile: () => setState(() => _tab = _profileTab),
        links: drawerLinks(context, widget.user),
        modeSwitch: modeSwitch(context, widget.user),
        items: const [
          AppNavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
          AppNavItem(icon: Icons.event_note_outlined, selectedIcon: Icons.event_note_rounded, label: 'Bookings'),
        ],
      ),
      body: ShellMenu(
        open: () => _scaffold.currentState?.openDrawer(),
        child: FadeIndexedStack(index: _tab, children: pages),
      ),
    );
  }
}
