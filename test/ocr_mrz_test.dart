import 'dart:convert';
import 'dart:developer';

import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_mrz/name_validation_data_class.dart';

import 'package:ocr_mrz/ocr_mrz.dart';
import 'package:ocr_mrz/ocr_mrz_settings_class.dart';
import 'package:ocr_mrz/online_parse_class.dart';
import 'package:ocr_mrz/session_ocr_handler_consensus.dart';

void main() {
  OcrMrzController controller = OcrMrzController();
  final OcrMrzSetting setting = OcrMrzSetting(
    nameValidationMode: NameValidationMode.exact
  );
  final SessionOcrHandlerConsensus sessionOcrHandler = SessionOcrHandlerConsensus(logger: controller.logger);
  final List<NameValidationData> nameValidations = [
    NameValidationData(lastName: "ALI", firstName: "MOLA"),
    NameValidationData(lastName: "SPEKCIMENK", firstName: "JOKAN"),
    // NameValidationData(lastName: "SPECIMEN", firstName: "JOAN"),

  ];

  test("OCR noise on check digits does not reset session at step 3", () {
    final noiseController = OcrMrzController();
    final noiseHandler = SessionOcrHandlerConsensus(logger: noiseController.logger);
    final good = OcrData(
      text:
          'P<ARMALAKYAN<<ARTUR<<<<<<<<<<<<<<<<<<<<<<<<<\n'
          'A003983889ARM9001011M2901019ARM<<<<<<<<<<<<<<0',
      lines: [
        OcrLine(text: 'P<ARMALAKYAN<<ARTUR<<<<<<<<<<<<<<<<<<<<<<<<<', cornerPoints: []),
        OcrLine(text: 'A003983889ARM9001011M2901019ARM<<<<<<<<<<<<<<0', cornerPoints: []),
      ],
    );
    final noisyCheckDigits = OcrData(
      text:
          'P<ARMALAKYAN<<ARTUR<<<<<<<<<<<<<<<<<<<<<<<<<\n'
          'A003983889ARM9001014M2901010ARM<<<<<<<<<<<<<<0',
      lines: [
        OcrLine(text: 'P<ARMALAKYAN<<ARTUR<<<<<<<<<<<<<<<<<<<<<<<<<', cornerPoints: []),
        OcrLine(text: 'A003983889ARM9001014M2901010ARM<<<<<<<<<<<<<<0', cornerPoints: []),
      ],
    );
    noiseHandler.handleSession(noiseController.aggregator, good, setting, nameValidations);
    final stepAfterGood = noiseController.aggregator.buildStatus().step!;
    expect(stepAfterGood, greaterThanOrEqualTo(3));
    noiseHandler.handleSession(noiseController.aggregator, noisyCheckDigits, setting, nameValidations);
    expect(noiseController.aggregator.buildStatus().step, greaterThanOrEqualTo(3));
  });

  test('Portuguese TD1 citizen card reaches step 5 with document number', () {
    final ctrl = OcrMrzController();
    final handler = SessionOcrHandlerConsensus(logger: ctrl.logger);
    const ocrText = '''
I<PRT309825784<ZX57<<<<<<<<<<<<<<<
0605014M2705147PRT<<<<<<<<<<<<<<<0
CARVALHAIS<FRADE<<RODRIGO<SANT
FILIACAO PARENTS LINE SERGIO CARVALHAIS
''';
    final ocr = OcrData(
      text: ocrText,
      lines: ocrText.split('\n').where((l) => l.trim().isNotEmpty).map((a) => OcrLine(text: a.trim(), cornerPoints: [])).toList(),
    );
    final relaxed = OcrMrzSetting(
      validateNames: false,
      validateDocNumberValid: false,
      validateCountry: false,
      validateNationality: false,
      validateBirthDateValid: false,
      validateExpiryDateValid: false,
      nameValidationMode: NameValidationMode.none,
    );
    final consensus = handler.handleSession(ctrl.aggregator, ocr, relaxed, []);
    expect(ctrl.aggregator.buildStatus().step, greaterThanOrEqualTo(5));
    expect(consensus.documentNumber, '309825784');
    expect(consensus.firstName, isNotNull);
    expect(consensus.lastName, isNotNull);
    expect(consensus.toResult().matchSetting(relaxed), isTrue);
  });

  test("Armenian passport TD3 reaches step 4", () {
    final armController = OcrMrzController();
    final armHandler = SessionOcrHandlerConsensus(logger: armController.logger);
    const ocrText =
        'P<ARMALAKYAN<<ARTUR<<<<<<<<<<<<<<<<<<<<<<<<<\n'
        'A003983889ARM9001011M2901019ARM<<<<<<<<<<<<<<0';
    final ocr = OcrData(
      text: ocrText,
      lines: ocrText.split('\n').map((a) => OcrLine(text: a, cornerPoints: [])).toList(),
    );
    final newCon = armHandler.handleSession(armController.aggregator, ocr, setting, nameValidations);
    expect(armController.aggregator.buildStatus().step, greaterThanOrEqualTo(4));
    expect(newCon.nationality, 'ARM');
    expect(newCon.documentNumber, 'A00398388');
  });

  test("asdsa", (){
    String ocrText = "P<KNASPECIMEN<<JOAN<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\nRX00001670KNA8309190F2011105B<4444<<<<<<<<56";

    OcrData ocr = OcrData(text: ocrText, lines: ocrText.split("\n").map((a)=>OcrLine(text: a, cornerPoints: [])).toList());

    final newCon = sessionOcrHandler.handleSession(controller.aggregator, ocr, setting, nameValidations);
    final result = newCon.toResult();
    if (result.matchSetting(setting)) {
     
      print("success");
      print(jsonEncode(result.toJson()));
    }else{
      print("${jsonEncode(result.toJson())}");
    }
  });
  test("asdsa2", (){
    final json = {
      "success": true,
      "errorCode": 0,
      "message": "",
      "response": {
        "id": "69b31e5dbd46b18ddd97cecb",
        "type": {
          "value": "P",
          "percent": 100,
          "checkDigit": "5"
        },
        "subType": {
          "value": "A",
          "percent": 100,
          "checkDigit": "0"
        },
        "documentNumber": {
          "value": "K0000000E",
          "percent": 100,
          "checkDigit": "4"
        },
        "birthDate": {
          "value": "770503",
          "percent": 100,
          "checkDigit": "8"
        },
        "expiryDate": {
          "value": "221030",
          "percent": 100,
          "checkDigit": "0"
        },
        "gender": {
          "value": "F",
          "percent": 100,
          "checkDigit": "5"
        },
        "nationality": {
          "value": "SGP",
          "percent": 100,
          "checkDigit": "9"
        },
        "issueCountry": {
          "value": "SGP",
          "percent": 100,
          "checkDigit": "9"
        },
        "name": {
          "value": "VONGARAYUNCEN",
          "percent": 18,
          "checkDigit": "5"
        }
      }
    };
    final res = ApiResponse.fromJson(json);
    final res2 = res.toOcrMrzResult();
    final res3 = res2.fixLines();
    print(jsonEncode(res3.toJson()));
  });



}
