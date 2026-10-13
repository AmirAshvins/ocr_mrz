import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_mrz/ocr_mrz.dart';

void main() {
  test('issue-date line survives after the 40-frame MRZ window', () {
    final aggregator = OcrMrzAggregator();
    aggregator.addFrameLines(const ['Date of issue', '31 MAR 2023']);

    for (var i = 0; i < 45; i++) {
      aggregator.addFrameLines(const [
        'P<UTOERIKSSON<<ANNA<MARIA<<<<<<<<<<<',
        'L898902C36UTO7408122F1204159ZE184226B<<<<<10',
      ]);
    }

    final lines = aggregator.allOcrLines;
    expect(lines, contains('Date of issue'));
    expect(lines, contains('Date of issue 31 MAR 2023'));
    expect(lines.where((line) => line.trim() == '31 MAR 2023'), isEmpty);
  });

  test('French délivrance line survives after the 40-frame MRZ window', () {
    final aggregator = OcrMrzAggregator();
    aggregator.addFrameLines(const ['Date de délivrance', '15 JAN/JAN 20']);

    for (var i = 0; i < 45; i++) {
      aggregator.addFrameLines(const [
        'P<CANERIKSSON<<ANNA<MARIA<<<<<<<<<<<',
        'L898902C36CAN7408122F1204159ZE184226B<<<<<10',
      ]);
    }

    final lines = aggregator.allOcrLines;
    expect(lines, contains('Date de délivrance'));
    expect(lines, contains('Date de délivrance 15 JAN/JAN 20'));
  });

  test('Canadian label stack keeps the issue value after MRZ frames', () {
    final aggregator = OcrMrzAggregator();
    aggregator.addFrameLines(const [
      'Date of birth / Date de naissance',
      'Date of issue / Date de délivrance',
      "Date of expiry / Date d'expiration",
      '01 JAN/JAN 90',
      '15 JAN/JAN 20',
      '15 JAN/JAN 30',
    ]);

    for (var i = 0; i < 45; i++) {
      aggregator.addFrameLines(const [
        'P<CANERIKSSON<<ANNA<MARIA<<<<<<<<<<<',
        'L898902C36CAN7408122F1204159ZE184226B<<<<<10',
      ]);
    }

    final kept = aggregator.allOcrLines.join('\n');
    expect(kept, contains('Date de délivrance'));
    expect(kept, contains('15 JAN/JAN 20'));
  });
}
