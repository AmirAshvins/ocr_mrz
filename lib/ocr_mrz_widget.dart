import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera_kit_plus/camera_kit_plus.dart';
import 'package:camera_kit_plus/camera_kit_plus_controller.dart';
import 'package:camera_kit_plus/enums.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:ocr_mrz/my_ocr_handler.dart';
import 'package:ocr_mrz/my_ocr_handler_new.dart';
import 'package:ocr_mrz/ocr_mrz_api_config.dart';
import 'package:ocr_mrz/ocr_mrz_settings_class.dart';
import 'package:ocr_mrz/online_parse_class.dart';
import 'package:ocr_mrz/orc_mrz_log_class.dart';
import 'package:ocr_mrz/passport_util.dart';
import 'package:ocr_mrz/session_logger.dart';
import 'package:ocr_mrz/session_ocr_handler_consensus.dart';
import 'package:ocr_mrz/session_status_class.dart';

import 'aggregator.dart';
import 'mrz_result_class_fix.dart';
import 'name_validation_data_class.dart';
import 'travel_doc_util.dart';
import 'visa_util.dart';
import 'ocr_mrz_log.dart';

export 'session_log_history_list_dialog.dart';

/// Whether this consensus frame should be accepted by the reader itself.
///
/// [autoConfirm] is false when a host quality gate owns acceptance. A relaxed
/// live [setting] makes [OcrMrzResult.matchSetting] true for every result, and
/// a null [countValidation] makes [OcrMrzAggregator.matchValidationCount]
/// return true on the first frame. Those two together used to accept every
/// OCR frame and wipe the session before a passport could stabilize.
///
/// Returns true only when [autoConfirm] is set and both the vote count and
/// the field setting match.
bool mrzFrameReadyToAutoConfirm({
  required bool autoConfirm,
  required OcrMrzAggregator aggregator,
  required OcrMrzConsensus consensus,
  required OcrMrzSetting setting,
  OcrMrzCountValidation? countValidation,
}) {
  if (!autoConfirm) return false;
  if (!aggregator.matchValidationCount(countValidation, setting)) return false;
  return consensus.toResult().matchSetting(setting);
}

/// Accepts [consensus] and clears the session when the reader owns confirmation.
///
/// [onFoundMrz] runs only when the frame is accepted. [controller] is then
/// reset so the next document starts clean. When [autoConfirm] is false the
/// aggregator is left intact so later frames can still accumulate a passport
/// MRZ.
///
/// Returns true after the session was reset.
bool applyMrzAutoConfirm({
  required OcrMrzController controller,
  required OcrMrzConsensus consensus,
  required OcrMrzSetting setting,
  OcrMrzCountValidation? countValidation,
  required bool autoConfirm,
  required void Function(OcrMrzResult result) onFoundMrz,
}) {
  if (!mrzFrameReadyToAutoConfirm(
    autoConfirm: autoConfirm,
    aggregator: controller.aggregator,
    consensus: consensus,
    setting: setting,
    countValidation: countValidation,
  )) {
    return false;
  }

  final result = consensus.toResult();
  result.scanDuration = DateTime.now().difference(controller._sessionStartTime);
  final mrzLines = controller.aggregator.buildMrz();
  if (mrzLines.isNotEmpty) {
    result.line1 = mrzLines[0];
    if (mrzLines.length > 1) {
      result.line2 = mrzLines[1];
    }
    if (mrzLines.length > 2) {
      result.line3 = mrzLines[2];
    }
  }
  onFoundMrz(result);
  controller.resetSession();
  return true;
}

class OcrMrzController extends CameraKitPlusController {
  final ValueNotifier<List<SessionStatus>> _sessionHistory =
      ValueNotifier<List<SessionStatus>>([SessionStatus.start()]);
  final OcrMrzAggregator aggregator = OcrMrzAggregator();
  late final SessionLogger logger;
  late DateTime _sessionStartTime;

  late final ValueNotifier<OcrMrzApiConfig?> _apiConfigNotifier;

  OcrMrzApiConfig? get apiConfig => _apiConfigNotifier.value;

  set apiConfig(OcrMrzApiConfig? newConfig) =>
      _apiConfigNotifier.value = newConfig;

  ValueNotifier<OcrMrzApiConfig?> get apiConfigNotifier => _apiConfigNotifier;

  OcrMrzController({SessionLogger? sessionLogger, OcrMrzApiConfig? apiConfig}) {
    logger = sessionLogger ?? SessionLogger();
    _sessionStartTime = DateTime.now();
    _apiConfigNotifier = ValueNotifier(apiConfig);
  }

  void changeApiConfig(OcrMrzApiConfig? newConfig) {
    apiConfig = newConfig;
  }

  flashOn() {
    changeFlashMode(CameraKitPlusFlashMode.on);
  }

  resetSession() {
    _sessionHistory.value = [SessionStatus.start()];
    aggregator.reset();
    logger.clear();
    _sessionStartTime = DateTime.now();
  }

  ValueNotifier<List<SessionStatus>> get getSessionHistory => _sessionHistory;

  void setSessionHistory(List<SessionStatus> sh) {
    _sessionHistory.value = [...sh];
  }

  void addSessionHistory(SessionStatus s) {
    _sessionHistory.value = [..._sessionHistory.value, s];
  }

  /// Disposes MRZ session resources and unbinds any per-view camera channel.
  void dispose() {
    logger.dispose();
    _apiConfigNotifier.dispose();
    unbind();
  }

  debug(
    String s,
    ParseAlgorithm alg,
    void Function(OcrMrzResult res) onFoundMrz,
  ) {
    final ocr = OcrData(
      text: s,
      lines:
          s
              .split("\n")
              .map((oc) => OcrLine(text: oc, cornerPoints: []))
              .toList(),
    );
    switch (alg) {
      case ParseAlgorithm.method1:
        handleOcrNew(ocr, onFoundMrz, OcrMrzSetting(), [], null, []);
        return;
      case ParseAlgorithm.method2:
        handleOcr(ocr, onFoundMrz, OcrMrzSetting(), [], null, []);
      case ParseAlgorithm.method3:
        handleOcr3(ocr, onFoundMrz, OcrMrzSetting(), [], null, []);
    }
  }
}

class OcrMrzReader extends StatefulWidget {
  final void Function(OcrMrzResult res) onFoundMrz;
  final void Function(OcrMrzLog log)? mrzLogger;
  final void Function(List<SessionStatus> sessionList)? onSessionChange;
  final void Function(OcrMrzConsensus sessionList)? onConsensusChanged;
  final List<DocumentType> filterTypes;
  final OcrMrzSetting? setting;
  final OcrMrzCountValidation? countValidation;
  final OcrMrzController controller;
  final List<NameValidationData>? nameValidations;
  final bool showFrame;
  final bool showZoom;
  final bool isActive;

  /// When false, consensus is still reported but this reader does not accept
  /// the frame or call [OcrMrzController.resetSession].
  ///
  /// Live passport scan turns this off. The relaxed match setting would
  /// otherwise match every frame and wipe the aggregator before the host
  /// quality gate can hold a read.
  final bool autoConfirm;

  OcrMrzReader({
    super.key,
    required this.onFoundMrz,
    this.setting,
    this.nameValidations,
    this.mrzLogger,
    this.filterTypes = const [],
    required this.controller,
    this.showFrame = true,
    this.showZoom = true,
    this.onSessionChange,
    this.countValidation,
    this.onConsensusChanged,
    this.isActive = true,
    this.autoConfirm = true,
  });

  @override
  State<OcrMrzReader> createState() => _OcrMrzReaderState();
}

class _OcrMrzReaderState extends State<OcrMrzReader> {
  late final SessionOcrHandlerConsensus _sessionOcrHandler;
  double zoom = 1.0;
  OcrMrzConsensus? improving;

  Timer? _apiTimer;
  final List<OcrData> _ocrDataBuffer = [];
  DateTime? _lastUiTick;

  @override
  void initState() {
    super.initState();
    _sessionOcrHandler = SessionOcrHandlerConsensus(
      logger: widget.controller.logger,
    );

    widget.controller.apiConfigNotifier.addListener(_onApiConfigChanged);
    if (widget.isActive) {
      _startApiTimer();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {});
          widget.controller.setOcrRotation(widget.setting?.rotation ?? 0);
          widget.controller.setMacro(widget.setting?.macro ?? false);
        }
      });
    });
  }

  void _onApiConfigChanged() {
    if (widget.isActive) {
      _startApiTimer();
    }
  }

  void _startApiTimer() {
    _apiTimer?.cancel();
    _ocrDataBuffer.clear();
    final apiConfig = widget.controller.apiConfig;
    if (apiConfig != null) {
      _apiTimer = Timer.periodic(apiConfig.interval, (_) => _makeApiCall());
    }
  }

  void _stopApiTimer() {
    _apiTimer?.cancel();
    _apiTimer = null;
  }

  /// Rebuilds overlay chrome at most ~5 Hz so live OCR does not flood the UI isolate.
  void _maybeRebuildUi() {
    final now = DateTime.now();
    if (_lastUiTick != null &&
        now.difference(_lastUiTick!) < const Duration(milliseconds: 200)) {
      return;
    }
    _lastUiTick = now;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _makeApiCall([bool asLog = false]) async {
    final apiConfig = widget.controller.apiConfig;
    if (!widget.isActive || _ocrDataBuffer.isEmpty || apiConfig == null) {
      return;
    }

    final List<OcrData> ocrDataToSend = List.of(_ocrDataBuffer);
    _ocrDataBuffer.clear();

    try {
      final request = http.MultipartRequest('POST', Uri.parse(apiConfig.url));
      request.headers.addAll(apiConfig.headers);

      final data = apiConfig.bodyBuilder(ocrDataToSend);
      request.fields['data'] = jsonEncode(data);

      if (apiConfig.attachPhoto) {
        ocrMrzLog("_makeApiCall with attach photo");
        final photoPath = await widget.controller.takePicture();
        if (photoPath != null) {
          final imageFile = File(photoPath);
          List<int> imageBytes = await imageFile.readAsBytes();

          img.Image? image = img.decodeImage(Uint8List.fromList(imageBytes));
          if (image != null) {
            img.Image resizedImage = image;
            if (apiConfig.photoMaxWidth != null &&
                image.width > apiConfig.photoMaxWidth!) {
              resizedImage = img.copyResize(
                image,
                width: apiConfig.photoMaxWidth,
              );
            }

            imageBytes = img.encodeJpg(
              resizedImage,
              quality: apiConfig.photoQuality,
            );
          }

          request.files.add(
            http.MultipartFile.fromBytes(
              'attachFiles',
              imageBytes,
              filename: 'mrz_scan.jpg',
            ),
          );
        }
      } else {
        ocrMrzLog("_makeApiCall without photo");
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (asLog) {
        return;
      }
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        ApiResponse res = ApiResponse.fromJson(jsonResponse);
        if (res.success) {
          ocrMrzLog("we got response from online parser ");
          final OcrMrzResult result = res.toOcrMrzResult();
          result.scanDuration = DateTime.now().difference(
            widget.controller._sessionStartTime,
          );

          if (result.valid.docNumberValid) {
            _handleResultFound(result);
          }
        }
      } else {
        ocrMrzLog("API call failed with status code ${response.statusCode}");
        widget.controller.logger.log(
          message: "API call failed with status code ${response.statusCode}",
          details: {'body': response.body},
        );
      }
    } catch (e) {
      ocrMrzLog("API call threw an exception ${e}");

      widget.controller.logger.log(
        message: "API call threw an exception",
        details: {'error': e.toString()},
      );
    }
  }

  void _handleResultFound(OcrMrzResult result) {
    if (!widget.isActive) return;
    _stopApiTimer();
    widget.controller.logger.flush(reason: LogFlushReason.success);
    widget.onFoundMrz(result);
    widget.controller.resetSession();
    _startApiTimer();
  }

  @override
  void didUpdateWidget(covariant OcrMrzReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        widget.controller.resumeCamera();
        _startApiTimer();
      } else {
        _stopApiTimer();
        widget.controller.pauseCamera();
      }
    }

    if (oldWidget.setting?.macro != widget.setting?.macro) {
      ocrMrzLog("should change macro");
      widget.controller.setMacro(widget.setting?.macro ?? false);
    }
    if (oldWidget.setting?.rotation != widget.setting?.rotation) {
      ocrMrzLog("should change rotation");
      widget.controller.setOcrRotation(widget.setting?.rotation ?? 0);
    }
  }

  @override
  void dispose() {
    _stopApiTimer();
    // CameraKitOcrPlusView already unbinds/disposes the channel in its dispose.
    widget.controller.apiConfigNotifier.removeListener(_onApiConfigChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const SizedBox.shrink();
    }
    return CameraKitOcrPlusView(
      showFrame: widget.showFrame,
      showZoomSlider: widget.showZoom,
      controller: widget.controller,
      onTextRead: (c) {
        if (!widget.isActive) {
          return;
        }

        if (widget.controller.apiConfig != null) {
          _ocrDataBuffer.add(c);
        }
        if (widget.setting?.algorithm == ParseAlgorithm.method3) {
          OcrMrzLog log = OcrMrzLog(
            rawText: c.text,
            rawMrzLines:
                c.lines
                    .where((a) => a.text.contains("<"))
                    .map((a) => a.text)
                    .toList(),
            fixedMrzLines: [],
            validation: OcrMrzValidation(),
            extractedData: {},
          );
          widget.mrzLogger?.call(log);
        } else {
          final setting = widget.setting ?? OcrMrzSetting();
          final newCon = _sessionOcrHandler.handleSession(
            widget.controller.aggregator,
            c,
            setting,
            widget.nameValidations ?? [],
          );
          improving = newCon;
          widget.onConsensusChanged?.call(newCon);
          // autoConfirm false keeps the aggregator. A relaxed live setting
          // matches every frame, and a null count validation matches
          // immediately, so accepting here would reset the passport session
          // before the host quality gate can hold it.
          applyMrzAutoConfirm(
            controller: widget.controller,
            consensus: newCon,
            setting: setting,
            countValidation: widget.countValidation,
            autoConfirm: widget.autoConfirm,
            onFoundMrz: (result) {
              _makeApiCall(true);
              _handleResultFound(result);

              widget.controller.logger.flush();

              widget.onFoundMrz(result);
            },
          );
          if (mounted) {
            _maybeRebuildUi();
          }
        }
      },
    );
  }
}

void handleOcr(
  OcrData ocr,
  void Function(OcrMrzResult res) onFoundMrz,
  OcrMrzSetting? setting,
  List<NameValidationData>? nameValidations,
  void Function(OcrMrzLog log)? mrzLogger,
  List<DocumentType> filterTypes, {
  bool tryPassportFirst = true,
}) {
  try {
    Map<String, dynamic>? result;
    if (filterTypes.isEmpty || filterTypes.contains(DocumentType.passport)) {
      result = tryParseMrzFromOcrLines(
        ocr,
        setting ?? OcrMrzSetting(),
        nameValidations,
        mrzLogger,
      );
    }
    if (filterTypes.isEmpty || filterTypes.contains(DocumentType.visa)) {
      result ??= tryParseVisaMrzFromOcrLines(
        ocr,
        setting ?? OcrMrzSetting(),
        nameValidations,
        mrzLogger,
      );
    }
    if (filterTypes.isEmpty ||
        filterTypes.contains(DocumentType.travelDocument1)) {
      result ??= tryParseTD1FromOcrLines(
        ocr,
        setting ?? OcrMrzSetting(),
        nameValidations,
        mrzLogger,
      );
    }
    if (filterTypes.isEmpty ||
        filterTypes.contains(DocumentType.travelDocument2)) {
      result ??= tryParseTD2FromOcrLines(
        ocr,
        setting ?? OcrMrzSetting(),
        nameValidations,
        mrzLogger,
      );
    }

    if (result == null) {
      return;
    }

    final parsed = OcrMrzResult.fromJson(result);
    onFoundMrz(parsed);
  } catch (e, st) {
    ocrMrzLog(e.toString());
    ocrMrzLog(st.toString());
  }
}

void handleOcrNew(
  OcrData ocr,
  void Function(OcrMrzResult res) onFoundMrz,
  OcrMrzSetting? setting,
  List<NameValidationData>? nameValidations,
  void Function(OcrMrzLog log)? mrzLogger,
  List<DocumentType> filterTypes, {
  bool tryPassportFirst = true,
}) {
  try {
    var result = MyOcrHandler.handle(ocr, mrzLogger);
    if (result != null) {
      onFoundMrz(result);
    }
  } catch (e, st) {
    ocrMrzLog(e.toString());
    ocrMrzLog(st.toString());
  }
}

void handleOcr3(
  OcrData ocr,
  void Function(OcrMrzResult res) onFoundMrz,
  OcrMrzSetting? setting,
  List<NameValidationData>? nameValidations,
  void Function(OcrMrzLog log)? mrzLogger,
  List<DocumentType> filterTypes, {
  bool tryPassportFirst = true,
}) {
  try {
    var result = MyOcrHandlerNew.handle(ocr, mrzLogger);
    if (result != null) {
      onFoundMrz(result);
    }
  } catch (e, st) {
    ocrMrzLog(e.toString());
    ocrMrzLog(st.toString());
  }
}
