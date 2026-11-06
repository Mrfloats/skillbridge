import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/db.dart';
import '../../services/device_services.dart';
import '../../widgets/common.dart';

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
      if (user.role == Roles.provider) await Db.instance.updateProvider(user.uid, {'photoUrl': url});
    }, success: 'Photo updated');
  }

  Future<void> _editName(BuildContext context) async {
    final name = await textPrompt(context, 'Full name', hint: user.fullName, ok: 'Save', minLength: 3, keyboard: TextInputType.name);
    if (name == null || !context.mounted) return;
    await runGuarded(context, () async {
      await Db.instance.updateUser(user.uid, {'fullName': name});
      if (user.role == Roles.provider) await Db.instance.updateProvider(user.uid, {'fullName': name});
    });
  }

  Future<void> _addContact(BuildContext context) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add trusted contact'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(88, 44)), onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty || phone.text.trim().length < 9 || !context.mounted) return;
    final list = [...user.trustedContacts, TrustedContact(name.text.trim(), phone.text.trim())];
    await runGuarded(context, () => Db.instance.saveTrustedContacts(user.uid, list));
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
          child: Center(
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
          SectionTitle('Trusted contacts',
              trailing: user.trustedContacts.length < AppConfig.maxTrustedContacts
                  ? TextButton.icon(onPressed: () => _addContact(context), icon: const Icon(Icons.add_rounded), label: const Text('Add'))
                  : null),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('These people get an SMS with your location if you press SOS during a job.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          ),
          if (user.trustedContacts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Column(children: [
                  for (final tc in user.trustedContacts)
                    ListTile(
                      leading: const Icon(Icons.contact_emergency_outlined),
                      title: Text(tc.name),
                      subtitle: Text(tc.phone),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: 'Remove',
                        onPressed: () => Db.instance.saveTrustedContacts(user.uid, user.trustedContacts.where((x) => x != tc).toList()),
                      ),
                    ),
                ]),
              ),
            ),
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
          const SizedBox(height: 20),
          Center(child: Text('${AppConfig.appName} v1.0.0', style: t.bodySmall)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
