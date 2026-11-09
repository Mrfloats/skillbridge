// The Terms of Service and Privacy Policy shown in Settings.
//
// DRAFT: written from how the app works today, not by a lawyer. Have both reviewed
// (including against Zimbabwe's Cyber and Data Protection Act) and update `legalUpdated`
// before launch. If the money rules or the data the app collects change, update these too.

/// One titled section of a legal document.
typedef LegalSection = (String heading, String body);

const legalUpdated = '9 November 2026';

const termsOfService = <LegalSection>[
  (
    'About SkillBridge',
    'SkillBridge is a marketplace that connects clients with local service providers. '
        'SkillBridge is not a party to the work agreed between a client and a provider, and does not employ providers.',
  ),
  (
    'Your account',
    'You must give your real name, email address and phone number, and keep your password private. '
        'You are responsible for what happens on your account. You must be 18 or older to use SkillBridge.',
  ),
  (
    'Providers',
    'Providers must pass ID and selfie verification before they can take bookings. '
        'Providers set their own prices and must do the work they quote for, safely and to a fair standard.',
  ),
  (
    'Quotes and payment',
    'A booking is confirmed when the client accepts the provider\'s quote. '
        'The client pays the provider directly, in cash or by mobile money. SkillBridge does not hold or handle this money, '
        'and any refund is between the client and the provider.',
  ),
  (
    'Service charge',
    'Providers pay SkillBridge a service charge of 10% of the quoted price for each job. '
        'It is taken from the provider\'s prepaid balance when the job closes: when the client confirms the job is done, '
        'or 48 hours after the provider marks it complete. A provider whose balance does not cover the charge cannot send new quotes. '
        'Top-ups are made through PayNow. Unused balance can be withdrawn.',
  ),
  (
    'Cancellations and problems',
    'Either side can cancel a booking before the job starts. If something goes wrong during a job, '
        'the client can report a problem before confirming it is done. An admin then decides whether the service charge applies '
        'in full, in part or not at all.',
  ),
  (
    'Ratings',
    'Clients rate providers and providers rate clients after a job closes. Ratings must be honest. '
        'SkillBridge may hide reviews that are abusive or false.',
  ),
  (
    'Safety',
    'The SOS button alerts SkillBridge and your trusted contacts. It does not replace the police or an ambulance. '
        'In an emergency, call the emergency services first.',
  ),
  (
    'Conduct',
    'Do not use SkillBridge to harass anyone, to commit fraud, or to arrange work outside the app to avoid the service charge. '
        'SkillBridge may suspend accounts that break these terms.',
  ),
  (
    'Liability',
    'SkillBridge checks providers\' identity but does not guarantee their work. '
        'As far as the law allows, SkillBridge is not liable for loss or damage arising from work arranged through the app.',
  ),
  (
    'Changes and ending your account',
    'We may update these terms and will tell you in the app when we do. '
        'You can delete your account at any time in Settings, once you have no open bookings and no money on your balance.',
  ),
];

const privacyPolicy = <LegalSection>[
  (
    'What we collect',
    'Your name, email address, phone number and profile photo. For providers, also your ID document and selfie, '
        'your services and prices, the area you work in and your base location. '
        'Your bookings, the job address and any photos you add, your chat messages, ratings and reviews, '
        'your balance and payment history, and the device token we use to send you notifications.',
  ),
  (
    'Location',
    'Clients can attach their GPS location to a booking request, so the provider can find them. You can turn this off in Settings. '
        'Providers set a base location, which we use to show clients how far away they are. Clients see the distance, not the exact location. '
        'If you press SOS, we share your location with SkillBridge and your trusted contacts, even if location sharing is off.',
  ),
  (
    'How we use it',
    'To run bookings, chat and payments, to verify providers, to show ratings, to keep users safe, '
        'to handle disputes and support requests, and to send you notifications about your bookings.',
  ),
  (
    'Who sees it',
    'The client and provider on a booking see each other\'s name, phone number and the booking details. '
        'Other users see a provider\'s public profile and a client\'s average rating. '
        'ID documents are seen only by the provider and SkillBridge admins. '
        'Payments go through PayNow, which receives the details needed to process them. We do not sell your information.',
  ),
  (
    'Where it is stored',
    'Your information is stored with Google Firebase, in data centres that may be outside Zimbabwe.',
  ),
  (
    'How long we keep it',
    'While your account is open. When you delete your account, we remove your login, contact details, photos and ID documents. '
        'We keep booking, rating and payment records, under the name "Deleted user", so the other people on those jobs keep their history '
        'and we can meet our legal and accounting duties.',
  ),
  (
    'Your choices',
    'You can update your details on your profile, turn off location sharing in Settings, and delete your account in Settings. '
        'To ask for a copy of your information, contact support.',
  ),
  (
    'Contact',
    'Questions about your privacy: use Support in the app menu.',
  ),
];
