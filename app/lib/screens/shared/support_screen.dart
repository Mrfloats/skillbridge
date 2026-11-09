import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/api.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';

const supportTopics = {
  'booking': 'A booking',
  'payment': 'Payments or my balance',
  'account': 'My account',
  'safety': 'Safety',
  'other': 'Something else',
};

/// Send a message to the support team, or email them, and see past messages.
class SupportScreen extends StatefulWidget {
  final AppUser user;

  /// The user's past messages. Replaced in tests.
  final Stream<List<SupportTicket>> Function()? tickets;
  const SupportScreen({super.key, required this.user, this.tickets});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _form = GlobalKey<FormState>();
  final _message = TextEditingController();
  late final _tickets = widget.tickets?.call() ?? Db.instance.mySupportTickets(widget.user.uid);
  String? _topic;
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _sending = true);
    final ok = await runGuarded(context, () => Api.instance.contactSupport(_topic!, _message.text.trim()), success: 'Message sent. We will reply by email or phone.');
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _message.clear();
      setState(() => _topic = null);
      _form.currentState!.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Support')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Text('Send us a message', style: t.titleLarge),
        const SizedBox(height: 4),
        Text('Our team reads every message and replies by email or phone.', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
        const SizedBox(height: 16),
        Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _topic,
              decoration: const InputDecoration(labelText: 'What is it about?'),
              items: [for (final e in supportTopics.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() => _topic = v),
              validator: (v) => v == null ? 'Choose a topic' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _message,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Your message', hintText: 'Tell us what happened, and which booking if it is about one', alignLabelWithHint: true),
              validator: (v) => (v ?? '').trim().length < 10 ? 'Tell us a little more' : null,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
              label: const Text('Send message'),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email us'),
            subtitle: const Text(AppConfig.supportEmail),
            trailing: const Icon(Icons.open_in_new_rounded),
            onTap: () => launchUrl(Uri(scheme: 'mailto', path: AppConfig.supportEmail, queryParameters: {'subject': '${AppConfig.appName} support'})),
          ),
        ),
        StreamBuilder<List<SupportTicket>>(
          stream: _tickets,
          builder: (context, snap) {
            final tickets = snap.data ?? [];
            if (tickets.isEmpty) return const SizedBox.shrink();
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 12),
              Text('Your messages', style: t.titleLarge),
              const SizedBox(height: 8),
              for (final tk in tickets)
                Card(
                  child: ListTile(
                    title: Text(supportTopics[tk.topic] ?? 'Something else'),
                    subtitle: Text([
                      tk.message,
                      if (tk.reply.isNotEmpty) 'Reply: ${tk.reply}',
                      if (tk.createdAt != null) fmtDate(tk.createdAt!),
                    ].join('\n')),
                    isThreeLine: true,
                    trailing: Chip(
                      label: Text(tk.isOpen ? 'Open' : 'Closed'),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
            ]);
          },
        ),
      ]),
    );
  }
}
