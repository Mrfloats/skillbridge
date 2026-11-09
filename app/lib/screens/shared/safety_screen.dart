import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../../widgets/trusted_contacts.dart';

/// Emergency numbers, how SOS works, trusted contacts and safety tips (FR-9).
class SafetyScreen extends StatelessWidget {
  final AppUser user;
  const SafetyScreen({super.key, required this.user});

  static const _clientTips = [
    (Icons.verified_rounded, 'Book verified providers', 'Every provider\'s ID is checked. Look for the verified badge, and read their reviews.'),
    (Icons.chat_rounded, 'Keep it in the app', 'Agree the job and the price in the chat, so there is a record if something goes wrong.'),
    (Icons.badge_rounded, 'Check who arrives', 'Make sure the person at your door matches the name and photo on the booking.'),
    (Icons.share_location_rounded, 'Tell someone', 'Let a friend or family member know when a job is happening, especially at night.'),
    (Icons.payments_rounded, 'Pay when the work is done', 'Only pay the amount on the accepted quote. Never share your mobile money PIN.'),
  ];

  static const _providerTips = [
    (Icons.star_rounded, 'Check the client', 'Look at the client\'s rating and the job details before you accept.'),
    (Icons.chat_rounded, 'Keep it in the app', 'Agree the job and the price in the chat, so there is a record if something goes wrong.'),
    (Icons.share_location_rounded, 'Tell someone', 'Let a friend or family member know where you are working, especially at night.'),
    (Icons.do_not_disturb_on_rounded, 'Leave if you feel unsafe', 'You do not have to start or finish a job that feels unsafe. Leave, then press SOS or contact support.'),
    (Icons.payments_rounded, 'Get paid as agreed', 'Collect the amount on the accepted quote. Never share your mobile money PIN.'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Safety')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Card(
            color: c.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.emergency_rounded, color: c.onErrorContainer),
                  const SizedBox(width: 8),
                  Text('In an emergency', style: t.titleMedium?.copyWith(color: c.onErrorContainer)),
                ]),
                const SizedBox(height: 4),
                Text('Call the emergency services first.', style: t.bodyMedium?.copyWith(color: c.onErrorContainer)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (name, number) in AppConfig.emergencyNumbers)
                    ActionChip(
                      avatar: const Icon(Icons.call_rounded, size: 18),
                      label: Text('$name $number'),
                      onPressed: () => launchUrl(Uri(scheme: 'tel', path: number)),
                    ),
                ]),
              ]),
            ),
          ),
        ),
        const SectionTitle('The SOS button'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'While a job is on, an SOS button appears at the top of the booking. '
                'Pressing it sends your location and the booking details to the SkillBridge team and your trusted contacts straight away. '
                'It shares your location even if location sharing is off in Settings.',
                style: t.bodyMedium,
              ),
            ),
          ),
        ),
        TrustedContactsSection(user: user),
        const SectionTitle('Staying safe'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Column(children: [
              for (final (icon, title, body) in user.inProviderMode ? _providerTips : _clientTips) ListTile(leading: Icon(icon, color: c.primary), title: Text(title), subtitle: Text(body)),
            ]),
          ),
        ),
      ]),
    );
  }
}
