// Runs SkillBridge against the local Firebase emulators, with no real Firebase
// project and no real money. Start the emulators first (see README), then:
//   flutter run -t lib/main_local.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'main.dart';

/// The address an Android emulator uses to reach the host computer.
const _host = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppTheme.registerFontLicenses();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'demo-api-key',
      appId: '1:1234567890:android:0000000000000000',
      messagingSenderId: '1234567890',
      projectId: 'demo-skillbridge',
    ),
  );
  await FirebaseAuth.instance.useAuthEmulator(_host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(_host, 8080);
  FirebaseFunctions.instanceFor(region: AppConfig.functionsRegion).useFunctionsEmulator(_host, 5001);
  runApp(const SkillBridgeApp());
}
