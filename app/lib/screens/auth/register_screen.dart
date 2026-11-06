import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import 'auth_scaffold.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  String _role = Roles.client;
  bool _agree = false;
  bool _busy = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_agree) {
      showSnack(context, 'Please accept the terms and privacy policy.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService.instance.register(
        fullName: _name.text,
        email: _email.text,
        phone: _phone.text,
        password: _password.text,
        role: _role,
      );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
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
      title: 'Create your account',
      subtitle: 'Hire trusted help, or grow your business.',
      formKey: _form,
      children: [
          Text('I want to', style: t.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: Roles.client, icon: Icon(Icons.person_search), label: Text('Hire help')),
              ButtonSegment(value: Roles.provider, icon: Icon(Icons.handyman), label: Text('Offer services')),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          AnimatedSize(
            duration: Motion.medium,
            curve: Motion.emphasized,
            alignment: Alignment.topCenter,
            child: _role == Roles.provider
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text('You will upload your national ID and a selfie next. Clients see your profile once an admin approves it.', style: t.bodySmall),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.badge_outlined)),
            validator: (v) => (v ?? '').trim().split(' ').length >= 2 ? null : 'Enter your first and last name',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
            validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Mobile number', hintText: '0771 234 567', prefixIcon: Icon(Icons.phone_outlined)),
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
              return digits.length >= 9 ? null : 'Enter a valid mobile number';
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password', helperText: 'At least 8 characters', prefixIcon: Icon(Icons.lock_outline)),
            validator: (v) => (v ?? '').length >= 8 ? null : 'Use at least 8 characters',
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _agree,
            onChanged: (v) => setState(() => _agree = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('I agree to the Terms of Service and Privacy Policy'),
          ),
          const SizedBox(height: 12),
          GlowButton(label: 'Sign up', busy: _busy, onPressed: _submit),
      ],
    );
  }
}
