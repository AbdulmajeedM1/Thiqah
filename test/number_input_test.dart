import 'package:flutter_test/flutter_test.dart';
import 'package:trust_app/src/number_input.dart';

void main() {
  test('parses Arabic, Persian, Western and mixed digits and decimals', () {
    for (final input in ['٣٠٠٫٥٠', '۳۰۰٫۵۰', '300.50', '٣0۰.٥0']) {
      expect(parseLocalizedDecimal(input), 300.5, reason: input);
    }
    expect(parseLocalizedDecimal('  ١٢٫٢٥  '), 12.25);
    expect(parseLocalizedDecimal('٫٥'), .5);
    expect(parseLocalizedInteger('٧'), 7);
    expect(parseLocalizedInteger('۷'), 7);
    expect(parseLocalizedInteger('7'), 7);
    expect(parseLocalizedInteger('٧٫٥'), isNull);
  });

  test('accepts correctly grouped Arabic thousands separators', () {
    expect(parseLocalizedDecimal('١٬٢٣٤٫٥٠'), 1234.5);
    expect(parseLocalizedDecimal('۱۲٬۳۴۵٫۶۷'), 12345.67);
    expect(parseLocalizedDecimal('١٬٢٣٤٬٥٦٧٫٨٩'), 1234567.89);
    expect(parseLocalizedInteger('١٬٢٣٤'), 1234);
    expect(parseLocalizedDecimal('-١٬٢٣٤'), -1234);
  });

  test('does not reinterpret malformed or ambiguous number separators', () {
    for (final input in [
      null,
      '',
      'abc',
      '١٢٬٣٤',
      '١٢٣٤٬٥٦٧',
      '١٬٢٣٤٬٥',
      '٬١٢٣',
      '١٢٣٬',
      '١٫٢٫٣',
      '١٫٢٬٣٤٥',
      '٣٠٠,٥٠',
      '1,234',
    ]) {
      expect(parseLocalizedDecimal(input), isNull, reason: '$input');
      expect(parseLocalizedInteger(input), isNull, reason: '$input');
    }
  });
}
