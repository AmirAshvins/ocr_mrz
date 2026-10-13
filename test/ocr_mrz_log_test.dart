import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_mrz/ocr_mrz_log.dart';

void main() {
  tearDown(() {
    OcrMrzLogging.configure(silentLogs: true);
  });

  test('ocr logs are silent by default', () {
    expect(OcrMrzLogging.silentLogs, isTrue);
    ocrMrzLog('hidden');
  });

  test('configure can enable ocr diagnostics', () {
    OcrMrzLogging.configure(silentLogs: false);
    expect(OcrMrzLogging.silentLogs, isFalse);
    ocrMrzLog('visible');
  });
}
