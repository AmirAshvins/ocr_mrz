// To parse this JSON data, do
//
//     final sessionStatus = sessionStatusFromJson(jsonString);

import 'dart:convert';

import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';
import 'package:ocr_mrz/mrz_result_class_fix.dart';

import 'orc_mrz_log_class.dart';

SessionStatus sessionStatusFromJson(String str) => SessionStatus.fromJson(json.decode(str));

String sessionStatusToJson(SessionStatus data) => json.encode(data.toJson());

class SessionStatus {
  final DateTime? dateTime;
  final int? step;
  final String? details;
  final OcrData? ocr;
  final OcrMrzValidation? validation;
  final String? type;
  final String? format;
  final String? docNumber;
  final String? firstName;
  final String? lastName;
  final String? birthDate;
  final String? expiryDate;
  final String? issueDate;
  final String? countryCode;
  final String? nationality;
  final String? issuing;
  final String? docCode;
  final String? sex;
  final String? optional;
  final String? name;
  final String? finalCheckValue;
  final String? dateSexStr;
  final String? line1;
  final String? line2;
  final String? line3;
  final String? birthCheck;
  final String? expCheck;
  final String? numberCheck;
  final String? finalCheck;
  final String? logDetails;

  SessionStatus({
    this.dateTime,
    this.step,
    this.details,
    this.ocr,
    this.validation,
    this.type,
    this.format,
    this.docNumber,
    this.firstName,
    this.lastName,
    this.birthDate,
    this.expiryDate,
    this.issueDate,
    this.countryCode,
    this.nationality,
    this.issuing,
    this.docCode,
    this.sex,
    this.optional,
    this.name,
    this.finalCheckValue,
    this.dateSexStr,
    this.line1,
    this.line2,
    this.line3,
    this.birthCheck,
    this.expCheck,
    this.numberCheck,
    this.finalCheck,
    this.logDetails,
  });

  SessionStatus copyWith({
    DateTime? dateTime,
    int? step,
    String? details,
    OcrData? ocr,
    OcrMrzValidation? validation,
    String? type,
    String? format,
    String? docNumber,
    String? firstName,
    String? lastName,
    String? birthDate,
    String? expiryDate,
    String? issueDate,
    String? countryCode,
    String? nationality,
    String? issuing,
    String? docCode,
    String? sex,
    String? optional,
    String? name,
    String? finalCheckValue,
    String? dateSexStr,
    String? line1,
    String? line2,
    String? line3,
    String? birthCheck,
    String? expCheck,
    String? numberCheck,
    String? finalCheck,
    String? logDetails,
  }) => SessionStatus(
    dateTime: dateTime ?? this.dateTime,
    step: step ?? this.step,
    details: details ?? this.details,
    ocr: ocr ?? this.ocr,
    validation: OcrMrzValidation.fromJson((validation ?? this.validation ?? OcrMrzValidation()).toJson()),
    type: type ?? this.type,
    format: format ?? this.format,
    docNumber: docNumber ?? this.docNumber,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    birthDate: birthDate ?? this.birthDate,
    expiryDate: expiryDate ?? this.expiryDate,
    issueDate: issueDate ?? this.issueDate,
    countryCode: countryCode ?? this.countryCode,
    nationality: nationality ?? this.nationality,
    issuing: issuing ?? this.issuing,
    docCode: docCode ?? this.docCode,
    sex: sex ?? this.sex,
    optional: optional ?? this.optional,
    name: name ?? this.name,
    finalCheckValue: finalCheckValue ?? this.finalCheckValue,
    dateSexStr: dateSexStr ?? this.dateSexStr,
    line1: line1 ?? this.line1,
    line2: line2 ?? this.line2,
    line3: line3 ?? this.line3,
    birthCheck: birthCheck ?? this.birthCheck,
    numberCheck: numberCheck ?? this.numberCheck,
    expCheck: expCheck ?? this.expCheck,
    finalCheck: finalCheck ?? this.finalCheck,
    logDetails: logDetails ?? this.logDetails,
  );

  factory SessionStatus.fromJson(Map<String, dynamic> json) => SessionStatus(
    dateTime: json["dateTime"] == null ? null : DateTime.parse(json["dateTime"]),
    step: json["step"],
    details: json["details"],
    ocr: json["ocr"],
    validation: json["validation"] == null ? null : OcrMrzValidation.fromJson(json["validation"]),
    type: json["type"],
    format: json["format"],
    docNumber: json["docNumber"],
    firstName: json["firstName"],
    lastName: json["lastName"],
    birthDate: json["birthDate"],
    expiryDate: json["expiryDate"],
    issueDate: json["issueDate"],
    countryCode: json["countryCode"],
    nationality: json["nationality"],
    issuing: json["issuing"],
    docCode: json["docCode"],
    sex: json["sex"],
    optional: json["optional"],
    name: json["name"],
    finalCheckValue: json["finalCheckValue"],
    dateSexStr: json["dateSexStr"],
    line1: json["line1"],
    line2: json["line2"],
    line3: json["line3"],
    birthCheck: json["birthCheck"],
    expCheck: json["expCheck"],
    numberCheck: json["numberCheck"],
    finalCheck: json["finalCheck"],
    logDetails: json["logDetails"],
  );

  Map<String, dynamic> toJson() => {
    "dateTime": dateTime?.toIso8601String(),
    "step": step,
    "details": details,
    "ocr": ocr?.toJson(),
    "validation": validation?.toJson(),
    "type": type,
    "format": format,
    "docNumber": docNumber,
    "firstName": firstName,
    "lastName": lastName,
    "birthDate": birthDate,
    "expiryDate": expiryDate,
    "issueDate": issueDate,
    "countryCode": countryCode,
    "nationality": nationality,
    "issuing": issuing,
    "docCode": docCode,
    "sex": sex,
    "optional": optional,
    "name": name,
    "finalCheckValue": finalCheckValue,
    "dateSexStr": dateSexStr,
    "line1": line1,
    "line2": line2,
    "line3": line3,
    "birthCheck": birthCheck,
    "expCheck": expCheck,
    "numberCheck": numberCheck,
    "finalCheck": finalCheck,
    "logDetails": logDetails,
  };

  factory SessionStatus.start() => SessionStatus(dateTime: DateTime.now(), step: 0, details: 'Start', ocr: OcrData(text: "", lines: []));

  String get getFinalCheckValue => "${docNumber ?? ''}${numberCheck ?? ''}${birthDate ?? ''}${birthCheck ?? ''}${expiryDate ?? ''}${expCheck ?? ''}${optional ?? ''}";

  OcrMrzResult get getOcrResult => OcrMrzResult(
    line1: line1 ?? '',
    line2: line2 ?? '',
    format: type ?? 'unknown',
    documentCode: docCode ?? '',
    documentType: type ?? 'unknown',
    mrzFormat: type,
    countryCode: countryCode ?? '',
    issuingState: countryCode ?? "",
    lastName: lastName ?? "",
    firstName: firstName ?? '',
    documentNumber: docNumber ?? '',
    nationality: nationality ?? '',
    birthDate: _parseMrzDate(birthDate ?? ''),
    expiryDate: _parseMrzDate(expiryDate ?? ''),
    sex: sex ?? '',
    personalNumber: optional ?? '',
    optionalData: optional ?? '',
    valid: validation ?? OcrMrzValidation(),
    checkDigits: CheckDigits(document: false, birth: false, expiry: false, optional: false),
    ocrData: ocr ?? OcrData(text: "", lines: []),
  );

  List<String> get getLines => line3 == null ? [line1 ?? '', line2 ?? ''] : [line1 ?? '', line2 ?? '', line3 ?? ''];

  OcrMrzLog get getLog => OcrMrzLog(rawText: ocr?.text ?? '', rawMrzLines: getLines, fixedMrzLines: getLines, validation: validation ?? OcrMrzValidation(), extractedData: getOcrResult.toJson());

  @override
  String toString() {
    if (step == 0) {
      return "Step:$step\n$details\n";
    }
    if (step == 1) {
      return "Step:$step\n$details\nDates and Genders Guess$dateSexStr";
    }
    if (step == 2) {
      return "Step:$step\n$details\n Birth:$birthDate Sex:$sex Exp:$expiryDate";
    }
    if (step == 3) {
      return "Step:$step\n$details\n Birth:$birthDate Sex:$sex Exp:$expiryDate\nNationality :$nationality type:$type";
    }
    if (step == 4) {
      return "Step:$step\n$details\n Birth:$birthDate Sex:$sex Exp:$expiryDate\nNationality :$nationality type:$type\nNumber:$docNumber\nCode: $docCode    Country: $countryCode";
    }
    if (step == 5) {
      return "Step:$step\n$details\n$dateSexStr-->$birthDate $sex $expiryDate\n${validation.toString()}\nCode: $docCode    Country: $countryCode\nName: $firstName $lastName";
    }
    if (step == 6) {
      return "Step:$step\n$details\n$dateSexStr-->$birthDate $sex $expiryDate\n${validation.toString()}\nCode: $docCode    Country: $countryCode\nName: $firstName $lastName\nOptional:$optional   $finalCheck";
    }

    return "Step:$step";
  }

  @override
  bool operator ==(Object other) {
    return other is SessionStatus && jsonEncode(toJson()) == jsonEncode(other.toJson());
  }
}

DateTime? _parseMrzDate(String yymmdd) {
  if (!RegExp(r'^\d{6}$').hasMatch(yymmdd)) return null;

  final year = int.parse(yymmdd.substring(0, 2));
  final month = int.parse(yymmdd.substring(2, 4));
  final day = int.parse(yymmdd.substring(4, 6));

  // MRZ dates assume:
  // - birth: usually 1900–2029 (but safe to assume <= current year)
  // - expiry: usually 2000–2099
  final now = DateTime.now().year % 100;

  final fullYear = year <= now + 10 ? 2000 + year : 1900 + year;

  try {
    return DateTime.utc(fullYear, month, day);
  } catch (_) {
    return null;
  }
}
