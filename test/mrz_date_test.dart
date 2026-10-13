import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_mrz/mrz_date.dart';
import 'package:ocr_mrz/ocr_mrz.dart';
import 'package:ocr_mrz/session_status_class.dart';

void main() {
  final clock = DateTime.utc(2026, 10, 13);

  test('birth years inside the expiry window stay in the 1900s', () {
    expect(
      parseMrzYymmdd('300115', field: MrzYymmddField.birth, now: clock),
      DateTime.utc(1930, 1, 15),
    );
    expect(
      parseMrzYymmdd('360101', field: MrzYymmddField.birth, now: clock),
      DateTime.utc(1936, 1, 1),
    );
    // 27 is also inside `year <= 26 + 10`, so it was read as 2027 before.
    expect(
      parseMrzYymmdd('270601', field: MrzYymmddField.birth, now: clock),
      DateTime.utc(1927, 6, 1),
    );
    expect(
      parseMrzYymmdd('900101', field: MrzYymmddField.birth, now: clock),
      DateTime.utc(1990, 1, 1),
    );
    expect(
      parseMrzYymmdd('260101', field: MrzYymmddField.birth, now: clock),
      DateTime.utc(2026, 1, 1),
    );
    expect(
      parseMrzYymmdd('261013', field: MrzYymmddField.birth, now: clock),
      DateTime.utc(2026, 10, 13),
    );
  });

  test('expiry years 15 and 30 stay 2015 and 2030', () {
    expect(
      parseMrzYymmdd('150115', field: MrzYymmddField.expiry, now: clock),
      DateTime.utc(2015, 1, 15),
    );
    expect(
      parseMrzYymmdd('300115', field: MrzYymmddField.expiry, now: clock),
      DateTime.utc(2030, 1, 15),
    );
    expect(
      parseMrzYymmdd('360101', field: MrzYymmddField.expiry, now: clock),
      DateTime.utc(2036, 1, 1),
    );
  });

  test('a 1930 birth does not come back as a future date from consensus', () {
    final aggregator = OcrMrzAggregator();
    aggregator.addBirthDate('300615');
    aggregator.addExpiryDate('150101');
    final parsed = aggregator.build();
    expect(
      parsed.birthDate!.isAfter(
        DateTime.now().toUtc().add(const Duration(days: 1)),
      ),
      isFalse,
    );
    expect(parsed.expiryDate, DateTime.utc(2015, 1, 1));

    final accepted =
        SessionStatus(birthDate: '300615', expiryDate: '300115').getOcrResult;
    expect(
      accepted.birthDate!.isAfter(
        DateTime.now().toUtc().add(const Duration(days: 1)),
      ),
      isFalse,
    );
    expect(accepted.expiryDate, DateTime.utc(2030, 1, 15));
  });
}
