import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/db.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/common.dart';
import 'help_screen.dart';
import 'notifications_screen.dart';
import 'safety_screen.dart';
import 'settings_screen.dart';
import 'support_screen.dart';

/// The pages listed under the sections in the side menu, for clients and providers alike.
/// [context] must stay mounted after the menu closes, so pass the shell's context.
List<AppDrawerLink> drawerLinks(BuildContext context, AppUser user) {
  void open(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  void openSupport() => open(SupportScreen(user: user));
  return [
    AppDrawerLink(icon: Icons.settings_outlined, label: 'Settings', onTap: () => open(SettingsScreen(user: user))),
    AppDrawerLink(icon: Icons.help_outline_rounded, label: 'Help', onTap: () => open(HelpScreen(user: user, onContactSupport: openSupport))),
    AppDrawerLink(icon: Icons.support_agent_rounded, label: 'Support', onTap: openSupport),
    AppDrawerLink(icon: Icons.health_and_safety_outlined, label: 'Safety', onTap: () => open(SafetyScreen(user: user))),
    AppDrawerLink(
      icon: Icons.notifications_outlined,
      label: 'Notifications',
      onTap: () => open(NotificationsScreen(user: user)),
      count: () => Db.instance.notifications(user.uid).map((l) => l.where((n) => !n.isRead).length),
    ),
  ];
}

/// The button at the bottom of the side menu that swaps between the client and provider sides.
/// The app rebuilds on the other side as soon as the saved mode changes.
AppDrawerLink modeSwitch(BuildContext context, AppUser user) {
  if (user.inProviderMode) {
    return AppDrawerLink(
      icon: Icons.person_search_rounded,
      label: 'Client mode',
      onTap: () => runGuarded(context, () => AuthService.instance.setMode(user.uid, Roles.client)),
    );
  }
  return AppDrawerLink(
    icon: Icons.handyman_rounded,
    label: 'Provider mode',
    onTap: () async {
      if (user.hasProviderProfile) {
        await runGuarded(context, () => AuthService.instance.setMode(user.uid, Roles.provider));
        return;
      }
      final ok = await confirmDialog(
        context,
        'Offer your services?',
        'We will set up a provider profile for you. Add your services and verify your ID, and you can start taking jobs. '
            'You can switch back to client mode at any time from this menu.',
        ok: 'Get started',
      );
      if (ok && context.mounted) await runGuarded(context, () => AuthService.instance.becomeProvider(user));
    },
  );
}
