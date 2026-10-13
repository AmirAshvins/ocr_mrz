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
}
