import 'package:flutter_test/flutter_test.dart';
import 'package:skillbridge/core/format.dart';

void main() {
  test('money formats cents', () {
    expect(money(3550), 'US\$35.50');
    expect(money(0), 'US\$0.00');
  });

  test('parseMoneyToCents', () {
    expect(parseMoneyToCents('35.5'), 3550);
    expect(parseMoneyToCents('\$12'), 1200);
    expect(parseMoneyToCents('abc'), null);
  });

  test('phone normalisation', () {
    expect(toE164('0771234567'), '+263771234567');
    expect(toE164('263771234567'), '+263771234567');
    expect(toLocalPhone('+263771234567'), '0771234567');
  });

  test('distance Harare CBD to Chitungwiza is about 20 km', () {
    final km = distanceKm(-17.8292, 31.0522, -18.0127, 31.0756);
    expect(km, inInclusiveRange(18, 26));
  });
}
