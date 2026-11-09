import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/format.dart';
import '../../models/models.dart';

typedef _Faq = (String question, String answer);

/// Answers to common questions, for the user's role.
class HelpScreen extends StatelessWidget {
  final AppUser user;
  final VoidCallback? onContactSupport;
  const HelpScreen({super.key, required this.user, this.onContactSupport});

  static final _forClients = <_Faq>[
    (
      'How do I book a provider?',
      'Search for the service you need, open a provider\'s profile and choose a service. Pick a day, a time and the address, describe the job, then send the request. The provider replies with a quote.'
    ),
    ('How do I pay?', 'When you accept the quote, the booking is confirmed. You pay the provider directly, in cash or by mobile money. SkillBridge does not take payment from you or hold your money.'),
    ('Can I cancel a booking?', 'Yes, from the booking screen, any time before the provider sets off. Once the job has started, use "Report a problem" instead.'),
    (
      'What if the job is not done properly?',
      'Do not confirm the job. Tap "Report a problem" on the booking and explain what went wrong. An admin will look into it. Refunds are agreed between you and the provider.'
    ),
    ('Are providers checked?', 'Yes. Every provider sends an ID document and a selfie, which our team checks before they can take bookings. Look for the verified badge.'),
    ('What does the job close mean?', 'When the provider marks the job complete, you confirm it is done. If you do not confirm or report a problem within 48 hours, the job closes on its own.'),
    ('How do ratings work?', 'After a job closes you can rate the provider, and the provider can rate you. Other providers see your average rating.'),
    ('What does the SOS button do?', 'During a job, SOS alerts the SkillBridge team and your trusted contacts with your location. In danger, call the police first. See Safety in the menu.'),
  ];

  static final _forProviders = <_Faq>[
    ('How do I get verified?', 'Open ID verification from your profile and send a photo of your ID and a selfie. Our team checks them. You can take bookings once you are verified.'),
    (
      'How does the service charge work?',
      'SkillBridge charges $commissionLabel of each job\'s quote. It comes off your prepaid balance when the job closes, not when you quote. For example, a ${money(5000)} job costs ${money(commissionOn(5000))}.'
    ),
    (
      'How do I top up my balance?',
      'Open Wallet and tap "Top up". Pay by EcoCash, OneMoney or card through PayNow. The money shows on your balance as soon as the payment goes through. The smallest top-up is ${money(AppConfig.minTopUpCents)}.'
    ),
    ('Why can\'t I send a quote?', 'Your balance must cover the service charge on the quote. If it is too low, or below zero, top up first.'),
    ('How do I get paid for a job?', 'The client pays you directly, in cash or by mobile money, as you agree. SkillBridge does not hold the money.'),
    ('What if the client does not confirm the job?', 'The job closes on its own 48 hours after you mark it complete, and the service charge is taken then.'),
    ('What if the client reports a problem?', 'The charge waits while an admin looks into it. They may charge in full, on part of the quote, or not at all.'),
    ('Can I get my balance back?', 'Yes. In Wallet, tap "Withdraw unused balance". Our team sends it by EcoCash or bank transfer.'),
    ('How do ratings work?', 'Clients rate you after each job, and you can reply to reviews once. You can also rate your clients.'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final faqs = user.inProviderMode ? _forProviders : _forClients;
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final (q, a) in faqs)
              ExpansionTile(
                title: Text(q, style: t.titleSmall),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedAlignment: Alignment.centerLeft,
                children: [Text(a)],
              ),
          ]),
        ),
        if (onContactSupport != null) ...[
          const SizedBox(height: 24),
          Text('Still need help?', style: t.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Center(child: OutlinedButton.icon(onPressed: onContactSupport, icon: const Icon(Icons.support_agent_rounded), label: const Text('Contact support'))),
        ],
      ]),
    );
  }
}
