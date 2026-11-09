import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'models/models.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/auth/email_verify_screen.dart';
import 'screens/auth/phone_verify_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/client/client_shell.dart';
import 'screens/provider/provider_shell.dart';
import 'services/auth_service.dart';
import 'services/db.dart';
import 'services/device_services.dart';
import 'services/settings_service.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppTheme.registerFontLicenses();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppSettings.instance.load();
  runApp(const SkillBridgeApp());
}

class SkillBridgeApp extends StatelessWidget {
  const SkillBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.instance.themeMode,
      builder: (context, themeMode, _) => MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        supportedLocales: const [Locale('en', 'GB'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AuthGate(),
      ),
    );
  }
}

/// Routes to the right home screen for the signed-in user's role (FR-1.6).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authChanges(),
      builder: (context, authSnap) {
        final user = authSnap.data;
        final Widget child;
        if (authSnap.connectionState == ConnectionState.waiting) {
          child = const BrandSplash(key: ValueKey('loading'));
        } else if (user == null) {
          child = const WelcomeScreen(key: ValueKey('welcome'));
        } else {
          child = UserGate(key: ValueKey(user.uid), uid: user.uid);
        }
        return AnimatedSwitcher(duration: Motion.slow, switchInCurve: Motion.emphasized, child: child);
      },
    );
  }
}

/// Admins skip verification. Everyone else needs a verified email or phone number.
bool mustVerify(AppUser user, {required bool emailVerified}) =>
    user.role != Roles.admin && !emailVerified && !user.phoneVerified;

class UserGate extends StatefulWidget {
  final String uid;
  @visibleForTesting
  final Stream<AppUser?> Function()? load;
  const UserGate({super.key, required this.uid, this.load});
  @override
  State<UserGate> createState() => _UserGateState();
}

class _UserGateState extends State<UserGate> {
  /// A new account's profile can take a moment to appear. After this long, offer a way out.
  static const _patience = Duration(seconds: 20);

  late Stream<AppUser?> _user;
  Timer? _patienceTimer;
  bool _waitedTooLong = false;
  bool _verifyByPhone = false;

  void _load() {
    _user = widget.load?.call() ?? Db.instance.user(widget.uid);
    _waitedTooLong = false;
    _patienceTimer?.cancel();
    _patienceTimer = Timer(_patience, () {
      if (mounted) setState(() => _waitedTooLong = true);
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _patienceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _user,
      builder: (context, snap) {
        final appUser = snap.data;
        final Widget child;
        if (appUser == null) {
          child = snap.hasError || _waitedTooLong
              ? _AccountProblem(key: const ValueKey('problem'), onRetry: () => setState(_load))
              : const BrandSplash(key: ValueKey('loading'));
        } else if (appUser.isSuspended) {
          child = const _SuspendedScreen(key: ValueKey('suspended'));
        } else if (mustVerify(appUser, emailVerified: AuthService.instance.emailVerified)) {
          child = _verifyByPhone
              ? PhoneVerifyScreen(key: const ValueKey('verify-phone'), user: appUser, onUseEmail: () => setState(() => _verifyByPhone = false))
              : EmailVerifyScreen(
                  key: const ValueKey('verify-email'),
                  user: appUser,
                  onVerified: () => setState(() {}),
                  onUsePhone: () => setState(() => _verifyByPhone = true),
                );
        } else {
          // Switching between client and provider mode swaps the whole home screen.
          child = _RoleHome(key: ValueKey((appUser.role, appUser.inProviderMode)), user: appUser);
        }
        return AnimatedSwitcher(duration: Motion.slow, switchInCurve: Motion.emphasized, child: child);
      },
    );
  }
}

class _RoleHome extends StatefulWidget {
  final AppUser user;
  const _RoleHome({super.key, required this.user});
  @override
  State<_RoleHome> createState() => _RoleHomeState();
}

class _RoleHomeState extends State<_RoleHome> {
  @override
  void initState() {
    super.initState();
    PushService.instance.register(widget.user.uid, isAdmin: widget.user.role == Roles.admin).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    if (user.role == Roles.admin) return AdminShell(user: user);
    return user.inProviderMode ? ProviderShell(user: user) : ClientShell(user: user);
  }
}

class _AccountProblem extends StatelessWidget {
  final VoidCallback onRetry;
  const _AccountProblem({super.key, required this.onRetry});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'We could not load your account',
          message: 'Check your connection and try again. If this keeps happening, log out and sign in again.',
          action: Column(mainAxisSize: MainAxisSize.min, children: [
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
            const SizedBox(height: 8),
            TextButton(onPressed: () => AuthService.instance.logout(), child: const Text('Log out')),
          ]),
        ),
      );
}

class _SuspendedScreen extends StatelessWidget {
  const _SuspendedScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: EmptyState(
          icon: Icons.block_rounded,
          title: 'Account suspended',
          message: 'Your account has been suspended. Contact ${AppConfig.supportEmail} for help.',
          action: OutlinedButton(onPressed: AuthService.instance.logout, child: const Text('Log out')),
        ),
      );
}
