# SkillBridge

A mobile marketplace that connects clients in Harare with ID-verified local service providers. Clients can book a provider, accept a quote and pay them directly, chat in the app, leave ratings and raise an SOS alert. Providers pay a 10% service charge per job from a prepaid balance. Built from the SkillBridge SRS v1.0, a successor to HandyLink.

```
skillbridge/
├── app/                  Flutter app (Android + iOS)
│   ├── lib/
│   │   ├── core/         theme, constants, formatting helpers
│   │   ├── models/       Firestore data classes
│   │   ├── services/     auth, Firestore, Cloud Functions, photos, location, push
│   │   ├── widgets/      shared UI pieces
│   │   └── screens/      auth · client · provider · shared · admin
│   ├── test/             unit tests
│   └── setup_platforms.sh
├── functions/            Cloud Functions (TypeScript): bookings, service charge, PayNow top-ups, trust & safety
├── firestore.rules       security rules: money and status are server-only
├── firestore.indexes.json
├── firebase.json
└── scripts/              make-admin.js, seed-categories.js
```

## What's in v1.0

| Area | SRS | Where |
|---|---|---|
| Email + password sign-up, role choice, email or SMS verification | FR-1 | `screens/auth/`, `services/auth_service.dart` |
| Provider ID + selfie upload, admin approve/reject, Verified badge | FR-2 | `provider/verification_screen.dart`, `admin/verification_review_screen.dart`, `functions/src/trust.ts` |
| Provider profile, services and prices, service radius, availability, portfolio | FR-3 | `provider/provider_setup_screen.dart` |
| Search by category or keyword, filter by distance or rating, sort, "Find nearest" | FR-4 | `client/search_screen.dart`, `Db.searchProviders` |
| Request → quote → accept → on the way → in progress → complete → confirm | FR-5 | `shared/booking_detail_screen.dart`, `functions/src/bookings.ts` |
| Double-booking prevention (slot locks), reschedule by agreement, cancellation rules, 24 h request expiry | FR-5.4–5.7 | `bookings.ts` |
| Direct payment to the provider, 10% service charge from a prepaid balance, PayNow (EcoCash, OneMoney, card) top-ups, auto-close after 48 h, wallet and withdrawals | FR-6 | `functions/src/bookings.ts`, `functions/src/payments.ts`, `shared/wallet_screen.dart` |
| In-app chat with photos, read ticks, report message | FR-7 | `shared/chat_screen.dart` |
| One review per booking, average rating, provider reply, admin hide | FR-8 | `Db.submitReview`, `trust.ts` |
| Providers rate clients after a closed job, and see a client's average before taking a job | FR-8.5 | `trust.ts` (`rateClient`), `shared/booking_detail_screen.dart` |
| SOS to admins and trusted contacts, with location | FR-9 | `booking_detail_screen.dart`, `trust.ts` (`onSosCreated`) |
| Push and in-app notifications | FR-10 | `helpers.ts` (`notify`), `shared/notifications_screen.dart` |
| Provider dashboard: earnings today/week/month, schedule, reviews | FR-11 | `provider/provider_dashboard_screen.dart` |
| Admin console: SOS, verification queue, disputes, payouts, support messages, users, reports, audit log | FR-12 | `admin/admin_shell.dart` |
| Side menu: Settings (appearance, language, location sharing, legal documents, app version, delete account), Help, Support, Safety, Notifications | — | `widgets/app_drawer.dart`, `screens/shared/drawer_links.dart`, `functions/src/account.ts` |
| One account, two modes: switch between Client mode and Provider mode in the side menu. A client's first switch creates an unverified provider profile. Only providers have a wallet. | — | `AppUser.inProviderMode`, `AuthService.becomeProvider`, `firestore.rules` |

Business rules live in `functions/src/config.ts`: the service charge, the auto-close window, the minimum top-up and the minimum withdrawal. The app shows the charge and the minimum top-up from `AppConfig` in `app/lib/core/constants.dart`, so change those together.

## Set up

You need the Flutter SDK (3.22 or newer), Node 22, the Firebase CLI (`npm i -g firebase-tools`) and the FlutterFire CLI (`dart pub global activate flutterfire_cli`).

### 1. Firebase project

1. Create a project at console.firebase.google.com and upgrade to the **Blaze** plan. Cloud Functions and outbound calls to PayNow need it.
2. Enable **Authentication**: Email/Password and Phone. For SMS, also allow your countries under Authentication → Settings → SMS region policy.
3. Create **Firestore** in production mode. Location: `europe-west1` or `africa-south1`.
4. Enable **Cloud Messaging**. Photos are saved in Firestore, so Cloud Storage is not needed.
5. In this folder, run `firebase login` and then `firebase use --add` to pick the project.

### 2. Backend

```bash
cd functions && npm install && cd ..
firebase functions:secrets:set PAYNOW_INTEGRATION_ID
firebase functions:secrets:set PAYNOW_INTEGRATION_KEY
firebase deploy --only firestore,functions
```

After the first deploy, copy the `paynowResult` function URL into `functions/.env` as `PAYNOW_RESULT_URL=https://...` and deploy the functions again. Get PayNow test credentials from paynow.co.zw under Integrations. In test mode, EcoCash payments succeed using PayNow's test numbers.

Seed categories and make yourself admin. You need a service-account key from Project settings → Service accounts:

```bash
cd functions
GOOGLE_APPLICATION_CREDENTIALS=../key.json node ../scripts/seed-categories.js
# register in the app first, then:
GOOGLE_APPLICATION_CREDENTIALS=../key.json node ../scripts/make-admin.js you@example.com
```

### 3. App

```bash
cd app
bash setup_platforms.sh      # creates android/ and ios/, adds permissions
flutterfire configure        # writes lib/firebase_options.dart
flutter run
```

For SMS verification on Android, add your debug SHA-1 and SHA-256 under Firebase → Project settings → Your apps (`cd android && ./gradlew signingReport`). On iOS, upload an APNs key in Cloud Messaging settings for push and silent phone verification.

### Run locally without real money

```bash
firebase emulators:start
```

To point the app at the emulators, add these lines after `Firebase.initializeApp` in `main.dart` (Android emulator host shown):

```dart
FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
FirebaseFunctions.instanceFor(region: 'europe-west1').useFunctionsEmulator('10.0.2.2', 5001);
```

### Test the money rules

```bash
cd functions && npm test
```

This runs the real functions on the emulators, with a local stand-in for PayNow. The emulators need Java 21 or newer. Android Studio includes one, which you can select by pointing `JAVA_HOME` at its `jbr` folder.

## How money moves

1. The provider tops up a prepaid balance through PayNow, into the platform's merchant account. To send a quote, their balance must cover 10% of it.
2. The client accepts the quote and pays the provider directly, in cash or by mobile money. SkillBridge never holds this money.
3. The provider marks the job done. The client confirms, or 48 hours pass, and the job closes. 10% of the quote then comes off the provider's balance. If they have several jobs open, this can take the balance below zero, and they can't send new quotes until they top up.
4. If the client raises a dispute, the charge waits for an admin to decide. "Job done" charges in full, "Not done" cancels with no charge, and "Part done" charges on a share of the quote. Admins can't move the job money, so any refund is between the client and the provider.
5. Providers can withdraw unused balance. An admin sends the money by EcoCash or bank, then marks it paid in the Payouts tab. PayNow has no automated payout API, so this step is manual.

Bookings paid into escrow before direct payment was introduced still settle the old way: their funds stay held until the job is released, refunded or split. That code can go once none are left.

Only Cloud Functions can change balances, payment state or booking status. The Firestore rules block the app from writing those fields (NFR-2.4).

## Known gaps / next steps

- **SMS to trusted contacts:** SOS messages are queued in the `smsQueue` collection. Connect an SMS gateway (Africa's Talking, Twilio, or the Firebase "Trigger Email/SMS" extensions) to deliver them.
- **Map view:** results are shown as a list sorted by distance, and bookings have a "Directions" button that opens Google Maps. A live map needs `google_maps_flutter` and a Maps API key.
- **Search scale:** distance filtering runs on the device after a Firestore query. This is fine for a few thousand providers. Switch to geohash queries (`geoflutterfire_plus`) beyond that.
- **Shona and Ndebele:** strings are in English. Move them to ARB files with `flutter gen-l10n` to add translations. Settings lists both languages as "Coming soon".
- **Legal documents:** the Terms of Service and Privacy Policy in `app/lib/core/legal.dart` are drafts written from how the app works. Have them reviewed before launch.
- **Emergency numbers:** check the numbers on the Safety page (`AppConfig.emergencyNumbers`) before launch.
- **Notification muting (FR-10.3)** is low priority and not built yet.
Log in. Use client@example.com or provider@example.com, both with the password password123.