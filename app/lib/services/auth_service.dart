import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../models/models.dart';

/// Registration, login, and email or phone verification (FR-1.1 – FR-1.5).
class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String get uid => _auth.currentUser!.uid;
  Stream<User?> authChanges() => _auth.authStateChanges();

  Future<void> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final user = cred.user!;
    await user.updateDisplayName(fullName.trim());
    final batch = _db.batch();
    batch.set(_db.collection('users').doc(user.uid), {
      'fullName': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'phone': toE164(phone),
      'role': role,
      'isSuspended': false,
      'phoneVerified': false,
      'trustedContacts': [],
      'fcmTokens': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (role == Roles.provider) batch.set(_db.collection('providers').doc(user.uid), _newProviderProfile(fullName.trim(), toE164(phone)));
    try {
      await batch.commit();
    } catch (_) {
      await user.delete().catchError((_) {});
      rethrow;
    }
    // The verify screen offers a resend, so a failed send must not fail the sign-up.
    await user.sendEmailVerification().catchError((_) {});
  }

  /// A new, unverified provider profile. The Firestore rules only accept it in this state.
  static Map<String, dynamic> _newProviderProfile(String fullName, String phone) => {
        'fullName': fullName,
        'phone': phone,
        'bio': '',
        'experienceYears': 0,
        'categoryIds': [],
        'baseAddress': '',
        'serviceRadiusKm': 10,
        'workingHours': 'Mon-Sat 08:00-18:00',
        'isAvailable': true,
        'isVerified': false,
        'isSuspended': false,
        'verificationStatus': 'pending',
        'avgRating': 0,
        'reviewCount': 0,
        'completedJobs': 0,
        'portfolioUrls': [],
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// Shows the client or provider side of the app (side menu → mode switch).
  Future<void> setMode(String uid, String mode) => _db.collection('users').doc(uid).update({'mode': mode});

  /// Gives a client a provider profile and switches them to provider mode, in one step.
  /// They then set up their services and verify their ID before they can take jobs.
  Future<void> becomeProvider(AppUser user) async {
    final batch = _db.batch();
    batch.set(_db.collection('providers').doc(user.uid), _newProviderProfile(user.fullName, user.phone));
    batch.update(_db.collection('users').doc(user.uid), {'providerProfile': true, 'mode': Roles.provider});
    await batch.commit();
  }

  Future<void> login(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> resetPassword(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> logout() => _auth.signOut();

  /// Checks the password again before something that can't be undone, such as deleting the account.
  Future<void> confirmPassword(String password) async {
    final user = _auth.currentUser!;
    try {
      await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email ?? '', password: password));
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code == 'invalid-credential' || e.code == 'wrong-password' ? 'That password is not correct.' : friendlyAuthError(e));
    }
  }

  bool get emailVerified => _auth.currentUser?.emailVerified ?? false;

  Future<void> sendVerificationEmail() => _auth.currentUser!.sendEmailVerification();

  /// Asks Firebase again, because the link is opened outside the app.
  Future<bool> checkEmailVerified() async {
    await _auth.currentUser?.reload();
    return emailVerified;
  }

  /// Sends an SMS code. [onCodeSent] receives the verification id.
  Future<void> sendPhoneCode({
    required String phone,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String message) onError,
    required Future<void> Function() onAutoVerified,
    int? resendToken,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: toE164(phone),
      forceResendingToken: resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        await _linkPhone(credential);
        await onAutoVerified();
      },
      verificationFailed: (e) => onError(friendlyAuthError(e)),
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> confirmPhoneCode(String verificationId, String code) async {
    final credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code.trim());
    await _linkPhone(credential);
  }

  Future<void> _linkPhone(PhoneAuthCredential credential) async {
    final user = _auth.currentUser!;
    try {
      await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'provider-already-linked') rethrow;
    }
    // Refresh the ID token so security rules see the linked phone number.
    await user.getIdToken(true);
    await _db.collection('users').doc(user.uid).update({'phoneVerified': true});
  }

  /// Admin status comes from the custom claim set by scripts/make-admin.js.
  Future<bool> isAdmin() async {
    final token = await _auth.currentUser?.getIdTokenResult(true);
    return token?.claims?['admin'] == true;
  }
}

String friendlyAuthError(Object e) {
  if (e is FirebaseAuthException) {
    return switch (e.code) {
      'invalid-email' => 'That email address is not valid.',
      'email-already-in-use' => 'An account already exists with that email. Try logging in.',
      'weak-password' => 'Use at least 8 characters for your password.',
      'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Email or password is incorrect.',
      'user-disabled' => 'This account has been suspended. Contact support.',
      'too-many-requests' => 'Too many attempts. Wait a few minutes and try again.',
      'invalid-verification-code' => 'That code is not correct. Check the SMS and try again.',
      'credential-already-in-use' => 'This phone number is already linked to another account.',
      'operation-not-allowed' => 'Text messages are not available right now. Please verify by email instead.',
      'network-request-failed' => 'No internet connection. Check your network and try again.',
      _ => e.message ?? 'Something went wrong. Please try again.',
    };
  }
  return 'Something went wrong. Please try again.';
}
