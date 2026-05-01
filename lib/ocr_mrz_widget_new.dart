import 'dart:developer';

import 'package:camera_kit_plus/camera_kit_plus.dart';
import 'package:flutter/material.dart';
import 'package:ocr_mrz/mrz_parser/mrz_result.dart';
import 'package:ocr_mrz/mrz_parser/mrz_validation_settings.dart';
import 'package:ocr_mrz/ocr_mrz_new_controller.dart';

class OcrMrzReaderNew extends StatefulWidget {
  final void Function(MrzResult result) onFoundMrz;
  final void Function(Map<String, dynamic> progress)? onProgress;
  final OcrMrzControllerNew controller;
  final bool isActive;
  final bool showFrame;
  final bool showZoom;
  final MrzValidationSettings validationSettings;

  OcrMrzReaderNew({
    super.key,
    required this.onFoundMrz,
    required this.controller,
    this.onProgress,
    this.isActive = true,
    this.showFrame = true,
    this.showZoom = true,
    this.validationSettings = const MrzValidationSettings(),
  });

  @override
  State<OcrMrzReaderNew> createState() => _OcrMrzReaderNewState();
}

class _OcrMrzReaderNewState extends State<OcrMrzReaderNew> {
  // The state is now simple and holds no parser instance.
  // The controller is the single source of truth.

  @override
  Widget build(BuildContext context) {
    return CameraKitOcrPlusView(
      showFrame: widget.showFrame,
      showZoomSlider: widget.showZoom,
      controller: widget.controller,
      onTextRead: (ocrData) {
        if (!widget.isActive) {
          return;
        }

        try {
          // 1. Always use the parser from the controller.
          final result = widget.controller.mrzParser.parse(ocrData, settings: widget.validationSettings);

          // 2. Always get progress from the controller's parser.
          widget.onProgress?.call(widget.controller.mrzParser.getProgress(ocrData));

          if (result != null) {
            log('--- MRZ Found! ---');

            // 3. Call the user's callback first.
            widget.onFoundMrz(result);

            // 4. Then, tell the controller to reset the one and only session.
            widget.controller.resetSession();
          }
        } catch (e) {
          log('Error during MRZ parsing: $e');
        }
      },
    );
  }
}
