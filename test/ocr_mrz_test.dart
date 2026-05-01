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
