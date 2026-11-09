import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/db.dart';
import '../../services/device_services.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/common.dart';
import '../../widgets/trusted_contacts.dart';

/// Profile, photo and trusted contacts for SOS (FR-1.7, FR-9.3).
class ProfileScreen extends StatelessWidget {
  final AppUser user;
  final List<Widget> extraTiles;
  const ProfileScreen({super.key, required this.user, this.extraTiles = const []});

  Future<void> _changePhoto(BuildContext context) async {
    final f = await PhotoService.instance.pick();
    if (f == null || !context.mounted) return;
    await runGuarded(context, () async {
      final url = await PhotoService.instance.uploadPublic(f, user.uid);
      await Db.instance.updateUser(user.uid, {'photoUrl': url});
      if (user.hasProviderProfile) await Db.instance.updateProvider(user.uid, {'photoUrl': url});
    }, success: 'Photo updated');
  }

  Future<void> _editName(BuildContext context) async {
    final name = await textPrompt(context, 'Full name', hint: user.fullName, ok: 'Save', minLength: 3, keyboard: TextInputType.name);
    if (name == null || !context.mounted) return;
    await runGuarded(context, () async {
      await Db.instance.updateUser(user.uid, {'fullName': name});
      if (user.hasProviderProfile) await Db.instance.updateProvider(user.uid, {'fullName': name});
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    final palette = context.palette;
    return Scaffold(
      body: HeroScrollView(
        hero: HeroPanel(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Stack(children: [
            Center(
              child: Column(children: [
                Reveal(
                  child: SizedBox(
                    width: 116,
                    height: 116,
                    child: Stack(children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: palette.accent, width: 2)),
                          child: Avatar(url: user.photoUrl, name: user.fullName, radius: 46),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: IconButton.filled(
                          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                          padding: EdgeInsets.zero,
                          style: IconButton.styleFrom(backgroundColor: palette.accent, foregroundColor: palette.onAccent),
                          icon: const Icon(Icons.edit_rounded, size: 17),
                          tooltip: 'Change photo',
                          onPressed: () => _changePhoto(context),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Reveal(index: 1, child: Text(user.fullName, style: t.headlineMedium?.copyWith(color: Colors.white), textAlign: TextAlign.center)),
                const SizedBox(height: 2),
                Reveal(index: 2, child: Text(user.email, style: t.bodySmall?.copyWith(color: Colors.white.withAlpha(205)))),
              ]),
            ),
            if (ShellMenu.button(context, onHero: true) case final menu?) Positioned(left: 0, top: 0, child: menu),
          ]),
        ),
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Reveal(
              index: 3,
              child: Card(
                child: Column(children: [
                  ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: const Text('Name'),
                      subtitle: Text(user.fullName),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _editName(context)),
                  ListTile(
                    leading: const Icon(Icons.phone_outlined),
                    title: const Text('Phone'),
                    subtitle: Text(user.phone),
                    trailing: user.phoneVerified ? Icon(Icons.verified_rounded, color: palette.success) : null,
                  ),
                  ...extraTiles,
                ]),
              ),
            ),
          ),
          TrustedContactsSection(user: user),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: ListTile(
                leading: Icon(Icons.logout_rounded, color: c.error),
                title: Text('Log out', style: TextStyle(color: c.error)),
                onTap: () async {
                  if (await confirmDialog(context, 'Log out?', 'You will need to log in again.', ok: 'Log out')) {
                    await AuthService.instance.logout();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
