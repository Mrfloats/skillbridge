import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge/services/device_services.dart';

void main() {
  test('the same photo reference shares one image cache entry', () {
    expect(const StoredImage('images/a'), const StoredImage('images/a'));
    expect(const StoredImage('images/a').hashCode, const StoredImage('images/a').hashCode);
    expect(const StoredImage('images/a'), isNot(const StoredImage('images/b')));
  });
}
