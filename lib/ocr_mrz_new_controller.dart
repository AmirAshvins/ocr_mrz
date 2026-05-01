import 'package:camera_kit_plus/camera_kit_plus_controller.dart';
import 'package:flutter/material.dart';
import 'package:ocr_mrz/mrz_parser/mrz_parser.dart';
import 'package:ocr_mrz/ocr_mrz_api_config.dart';

/// A dedicated controller for the new `OcrMrzReaderNew` widget.
class OcrMrzControllerNew extends CameraKitPlusController {
  late final MrzParser mrzParser;
  late DateTime _sessionStartTime;
  late final ValueNotifier<OcrMrzApiConfig?> _apiConfigNotifier;

  OcrMrzApiConfig? get apiConfig => _apiConfigNotifier.value;

  set apiConfig(OcrMrzApiConfig? newConfig) => _apiConfigNotifier.value = newConfig;

  ValueNotifier<OcrMrzApiConfig?> get apiConfigNotifier => _apiConfigNotifier;

  OcrMrzControllerNew({OcrMrzApiConfig? apiConfig, int confidence = 3}) {
    _sessionStartTime = DateTime.now();
    _apiConfigNotifier = ValueNotifier(apiConfig);
    mrzParser = MrzParser(confidence: confidence);
  }

  void changeApiConfig(OcrMrzApiConfig? newConfig) {
    apiConfig = newConfig;
  }

  /// Resets the entire scanning session, including the parser's internal state.
  void resetSession() {
    mrzParser.reset();
    _sessionStartTime = DateTime.now();
  }

  @override
  void dispose() {
    _apiConfigNotifier.dispose();
  }
}
