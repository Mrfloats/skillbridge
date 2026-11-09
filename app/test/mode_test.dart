import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge/models/models.dart';

AppUser _user(String role, {String? mode, bool hasProviderProfile = false}) => AppUser(uid: 'u', fullName: 'T', email: 'e', phone: 'p', role: role, mode: mode, hasProviderProfile: hasProviderProfile);

void main() {
  test('people who signed up as providers start in provider mode and can switch to client mode', () {
    expect(_user('provider').inProviderMode, isTrue);
    expect(_user('provider').hasProviderProfile, isTrue);
    expect(_user('provider', mode: 'client').inProviderMode, isFalse);
    expect(_user('provider', mode: 'provider').inProviderMode, isTrue);
  });

  test('clients start in client mode, and need a provider profile for provider mode', () {
    expect(_user('client').inProviderMode, isFalse);
    expect(_user('client', mode: 'provider').inProviderMode, isFalse, reason: 'no provider profile yet');
    expect(_user('client', mode: 'provider', hasProviderProfile: true).inProviderMode, isTrue);
    expect(_user('client', mode: 'client', hasProviderProfile: true).inProviderMode, isFalse);
  });

  test('admins always get the admin console', () {
    expect(_user('admin', mode: 'provider', hasProviderProfile: true).inProviderMode, isFalse);
  });
}
