import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import 'auth_scaffold.dart';

/// Email link check before first use (FR-1.3). The app rechecks when the user
/// comes back from their email app, or when they tap the button.
class EmailVerifyScreen extends StatefulWidget {
  final AppUser user;
  final VoidCallback onVerified;
  final VoidCallback onUsePhone;
  @visibleForTesting
  final Future<bool> Function()? check;
  @visibleForTesting
  final Future<void> Function()? resend;
  const EmailVerifyScreen({super.key, required this.user, required this.onVerified, required this.onUsePhone, this.check, this.resend});
  @override
  State<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends State<EmailVerifyScreen> with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(quiet: true);
  }

  Future<void> _check({bool quiet = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final verified = await (widget.check?.call() ?? AuthService.instance.checkEmailVerified());
      if (!mounted) return;
      if (verified) {
        widget.onVerified();
      } else if (!quiet) {
        showSnack(context, 'Not verified yet. Open the link in the email first.', error: true);
      }
    } catch (e) {
      if (mounted && !quiet) showSnack(context, friendlyAuthError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await (widget.resend?.call() ?? AuthService.instance.sendVerificationEmail());
      if (mounted) showSnack(context, 'Email sent to ${widget.user.email}');
    } catch (e) {
      if (mounted) showSnack(context, friendlyAuthError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Verify your email',
      subtitle: 'We sent a link to ${widget.user.email}. Open it, then come back here.',
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          onPressed: () => AuthService.instance.logout(),
          child: const Text('Log out'),
        ),
      ],
      children: [
        Text("Can't find it? Check your spam folder.", textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        GlowButton(label: 'I have verified', busy: _busy, onPressed: _check),
        const SizedBox(height: 8),
        TextButton(onPressed: _busy ? null : _resend, child: const Text('Resend email')),
        TextButton(onPressed: widget.onUsePhone, child: const Text('Use a text message instead')),
      ],
    );
  }
}
