import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import 'auth_scaffold.dart';

/// SMS one-time password check before first use (FR-1.3).
class PhoneVerifyScreen extends StatefulWidget {
  final AppUser user;
  final VoidCallback onUseEmail;
  const PhoneVerifyScreen({super.key, required this.user, required this.onUseEmail});
  @override
  State<PhoneVerifyScreen> createState() => _PhoneVerifyScreenState();
}

class _PhoneVerifyScreenState extends State<PhoneVerifyScreen> {
  final _code = TextEditingController();
  String? _verificationId;
  int? _resendToken;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _send();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    await AuthService.instance.sendPhoneCode(
      phone: widget.user.phone,
      resendToken: _resendToken,
      onCodeSent: (id, token) {
        if (!mounted) return;
        setState(() {
          _verificationId = id;
          _resendToken = token;
          _busy = false;
        });
        showSnack(context, 'Code sent to ${widget.user.phone}');
      },
      onError: (msg) {
        if (!mounted) return;
        setState(() => _busy = false);
        showSnack(context, msg, error: true);
      },
      onAutoVerified: () async {},
    );
  }

  Future<void> _verify() async {
    if (_verificationId == null || _code.text.trim().length < 6) return;
    setState(() => _busy = true);
    try {
      await AuthService.instance.confirmPhoneCode(_verificationId!, _code.text);
    } catch (e) {
      if (mounted) showSnack(context, friendlyAuthError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AuthScaffold(
      title: 'Verify your phone',
      subtitle: 'Enter the 6-digit code we sent to ${widget.user.phone}',
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          onPressed: () => AuthService.instance.logout(),
          child: const Text('Log out'),
        ),
      ],
      children: [
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: t.headlineMedium?.copyWith(letterSpacing: 12),
          decoration: const InputDecoration(counterText: '', hintText: '------'),
          onChanged: (v) {
            if (v.length == 6) _verify();
          },
        ),
        const SizedBox(height: 24),
        GlowButton(label: 'Verify', busy: _busy, onPressed: _verify),
        const SizedBox(height: 8),
        TextButton(onPressed: _busy ? null : _send, child: const Text('Resend code')),
        TextButton(onPressed: widget.onUseEmail, child: const Text('Use email instead')),
      ],
    );
  }
}
