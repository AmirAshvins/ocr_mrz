import 'dart:developer' as dev;

/// Diagnostic switch for MRZ parser console logs.
class OcrMrzLogging {
  OcrMrzLogging._();

  /// When true, [ocrMrzLog] is a no-op.
  static bool silentLogs = true;

  /// Updates parser logging. Host apps call this once at bootstrap.
  ///
  /// [silentLogs] follows the host scanner/OCR flag.
  static void configure({bool? silentLogs}) {
    if (silentLogs == null) {
      return;
    }
    OcrMrzLogging.silentLogs = silentLogs;
  }
}

/// Logs an MRZ diagnostic when [OcrMrzLogging.silentLogs] is false.
void ocrMrzLog(String message) {
  if (OcrMrzLogging.silentLogs) {
    return;
  }
  dev.log(message, name: 'OcrMrz');
}
