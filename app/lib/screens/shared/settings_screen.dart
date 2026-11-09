import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/legal.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/auth_service.dart';
import '../../services/db.dart';
import '../../services/settings_service.dart';
import '../../widgets/common.dart';

/// App settings: appearance, language, location sharing, legal documents, version and account deletion.
class SettingsScreen extends StatelessWidget {
  final AppUser user;

  /// Reads the installed version. Replaced in tests, where there is no installed app.
  final Future<String> Function()? version;

  const SettingsScreen({super.key, required this.user, this.version});

  static Future<String> _installedVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  }

  bool get _isProvider => user.inProviderMode;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        const SectionTitle('Appearance'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: AppSettings.instance.themeMode,
            builder: (context, mode, _) => SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Phone'), icon: Icon(Icons.brightness_auto_rounded)),
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
              ],
              selected: {mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => AppSettings.instance.setThemeMode(s.first),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text('"Phone" follows your phone\'s light or dark setting.', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
        ),
        const SectionTitle('General'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.translate_rounded),
              title: const Text('Language'),
              subtitle: const Text('English'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _chooseLanguage(context),
            ),
            _isProvider ? _ShowAreaSwitch(uid: user.uid) : _ShareLocationSwitch(user: user),
          ]),
        ),
        const SectionTitle('Legal'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Terms of Service'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen(title: 'Terms of Service', sections: termsOfService))),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen(title: 'Privacy Policy', sections: privacyPolicy))),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('App version'),
              subtitle: FutureBuilder<String>(
                future: (version ?? _installedVersion)(),
                builder: (context, snap) => Text(snap.data ?? (snap.hasError ? 'Unknown' : '…')),
              ),
            ),
          ]),
        ),
        const SectionTitle('Account'),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: ListTile(
            leading: Icon(Icons.delete_forever_rounded, color: c.error),
            title: Text('Delete account', style: TextStyle(color: c.error)),
            subtitle: const Text('Permanently remove your account and personal details'),
            onTap: () => _deleteAccount(context),
          ),
        ),
      ]),
    );
  }

  Future<void> _chooseLanguage(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: const [
            ListTile(title: Text('English'), trailing: Icon(Icons.check_rounded)),
            ListTile(enabled: false, title: Text('chiShona'), subtitle: Text('Coming soon')),
            ListTile(enabled: false, title: Text('isiNdebele'), subtitle: Text('Coming soon')),
            SizedBox(height: 8),
          ]),
        ),
      );

  Future<void> _deleteAccount(BuildContext context) async {
    final password = TextEditingController();
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Delete your account?'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('This removes your login, contact details, photos${_isProvider ? ', services and ID documents' : ''}. It cannot be undone.\n\n'
                  'Your past bookings and ratings stay on record under the name "Deleted user".\n\n'
                  'You can only delete your account when you have no open bookings and no money on your balance.'),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Enter your password to confirm'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: c.error, foregroundColor: c.onError, minimumSize: const Size(88, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    final typed = password.text;
    password.dispose();
    if (ok != true || !context.mounted) return;
    if (typed.isEmpty) {
      showSnack(context, 'Enter your password to delete your account.', error: true);
      return;
    }
    final deleted = await runGuarded(context, () async {
      await AuthService.instance.confirmPassword(typed);
      await Api.instance.deleteAccount();
    });
    // The login no longer exists, so sign out here. The app returns to the welcome screen.
    if (deleted) await AuthService.instance.logout();
  }
}

class _ShareLocationSwitch extends StatefulWidget {
  final AppUser user;
  const _ShareLocationSwitch({required this.user});
  @override
  State<_ShareLocationSwitch> createState() => _ShareLocationSwitchState();
}

class _ShareLocationSwitchState extends State<_ShareLocationSwitch> {
  late final _user = Db.instance.user(widget.user.uid);

  @override
  Widget build(BuildContext context) => StreamBuilder<AppUser?>(
        stream: _user,
        initialData: widget.user,
        builder: (context, snap) => SwitchListTile(
          secondary: const Icon(Icons.my_location_rounded),
          title: const Text('Share my location with providers'),
          subtitle: const Text('Adds your GPS location to new booking requests, so the provider can find you. SOS always shares your location.'),
          isThreeLine: true,
          value: (snap.data ?? widget.user).shareLocation,
          onChanged: (on) => runGuarded(context, () => Db.instance.updateUser(widget.user.uid, {'shareLocation': on})),
        ),
      );
}

class _ShowAreaSwitch extends StatefulWidget {
  final String uid;
  const _ShowAreaSwitch({required this.uid});
  @override
  State<_ShowAreaSwitch> createState() => _ShowAreaSwitchState();
}

class _ShowAreaSwitchState extends State<_ShowAreaSwitch> {
  late final _provider = Db.instance.provider(widget.uid);

  @override
  Widget build(BuildContext context) => StreamBuilder<ProviderProfile?>(
        stream: _provider,
        builder: (context, snap) => SwitchListTile(
          secondary: const Icon(Icons.location_on_outlined),
          title: const Text('Show my area to clients'),
          subtitle: const Text('Clients see the area you work from, such as "Avondale". They always see how far away you are, never your exact location.'),
          isThreeLine: true,
          value: snap.data?.showArea ?? true,
          onChanged: snap.data == null ? null : (on) => runGuarded(context, () => Db.instance.updateProvider(widget.uid, {'showArea': on})),
        ),
      );
}

/// A legal document, section by section.
class LegalScreen extends StatelessWidget {
  final String title;
  final List<LegalSection> sections;
  const LegalScreen({super.key, required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SelectionArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
          Text('Last updated $legalUpdated', style: t.bodySmall),
          for (final (heading, body) in sections) ...[
            const SizedBox(height: 20),
            Text(heading, style: t.titleMedium),
            const SizedBox(height: 6),
            Text(body, style: t.bodyMedium),
          ],
        ]),
      ),
    );
  }
}
