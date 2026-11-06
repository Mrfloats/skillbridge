# SkillBridge

A mobile marketplace that connects clients in Harare with ID-verified local service providers. Clients can book a provider, pay through PayNow escrow, chat in the app, leave ratings and raise an SOS alert. Built from the SkillBridge SRS v1.0, a successor to HandyLink.

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
├── functions/            Cloud Functions (TypeScript): bookings, escrow, PayNow, trust & safety
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
| Request → quote → pay → on the way → in progress → complete → confirm | FR-5 | `shared/booking_detail_screen.dart`, `functions/src/bookings.ts` |
| Double-booking prevention (slot locks), reschedule by agreement, cancellation rules, 24 h request expiry | FR-5.4–5.7 | `bookings.ts` |
| PayNow (EcoCash, OneMoney, card) into escrow, auto-release after 48 h, 10% commission, wallet and withdrawals | FR-6 | `functions/src/payments.ts`, `shared/wallet_screen.dart` |
| In-app chat with photos, read ticks, report message | FR-7 | `shared/chat_screen.dart` |
| One review per booking, average rating, provider reply, admin hide | FR-8 | `Db.submitReview`, `trust.ts` |
| SOS to admins and trusted contacts, with location | FR-9 | `booking_detail_screen.dart`, `trust.ts` (`onSosCreated`) |
| Push and in-app notifications | FR-10 | `helpers.ts` (`notify`), `shared/notifications_screen.dart` |
| Provider dashboard: earnings today/week/month, schedule, reviews | FR-11 | `provider/provider_dashboard_screen.dart` |
| Admin console: SOS, verification queue, disputes, payouts, users, reports, audit log | FR-12 | `admin/admin_shell.dart` |

Business rules live in `functions/src/config.ts`: commission, the auto-release window, cancellation fees and the minimum withdrawal.

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

## How money moves

1. The client pays the quote through PayNow, into the platform's merchant account. The payment is marked `held`.
2. The provider marks the job done. The client confirms, or 48 hours pass, and the funds are released. The provider's wallet is credited with the fee minus 10%.
3. If the client raises a dispute, the money stays held until an admin releases it, refunds it or splits it.
4. Refunds and earnings go to the in-app wallet. Users request a withdrawal, and an admin sends the money by EcoCash or bank, then marks it paid in the Payouts tab. PayNow has no automated payout API, so this step is manual.

Only Cloud Functions can change balances, payment state or booking status. The Firestore rules block the app from writing those fields (NFR-2.4).

## Known gaps / next steps

- **SMS to trusted contacts:** SOS messages are queued in the `smsQueue` collection. Connect an SMS gateway (Africa's Talking, Twilio, or the Firebase "Trigger Email/SMS" extensions) to deliver them.
- **Map view:** results are shown as a list sorted by distance, and bookings have a "Directions" button that opens Google Maps. A live map needs `google_maps_flutter` and a Maps API key.
- **Search scale:** distance filtering runs on the device after a Firestore query. This is fine for a few thousand providers. Switch to geohash queries (`geoflutterfire_plus`) beyond that.
- **Shona and Ndebele:** strings are in English. Move them to ARB files with `flutter gen-l10n` to add translations.
- **Provider rating of clients (FR-8.5)** and **notification muting (FR-10.3)** are low priority and not built yet.
Log in. Use client@example.com or provider@example.com, both with the password password123.