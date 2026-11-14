import 'package:assetkeeper/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('peso parsing and display retain exact centavos', () {
    expect(parseCentavos('0.10') + parseCentavos('0.20'), 30);
    expect(parseCentavos('5500.25'), 550025);
    expect(parseCentavos('1.2'), 120);
    expect(parseCentavos('0'), 0);
    expect(money(123456789), '₱1,234,567.89');
    expect(priceInput(9), '0.09');
  });
  test('invalid prices are rejected rather than rounded', () {
    for (final text in [
      '',
      '-1',
      'NaN',
      '1e5',
      '5.555',
      '1,000',
      '99999999999',
    ]) {
      expect(() => parseCentavos(text), throwsFormatException);
    }
  });
}
