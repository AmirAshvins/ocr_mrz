import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';
import 'package:ocr_mrz/constant_data_class.dart';
import 'package:ocr_mrz/document_class.dart';

enum MrzFormat { TD3, MRV_A, MRV_B, TD1, TD2, unknown }

enum DocumentType { passport, visa, travelDocument1, travelDocument2 }

class OcrMrzResult {
  DocumentType get type =>
      documentType == "P"
          ? DocumentType.passport
          : documentType == "V"
          ? DocumentType.visa
          : mrzFormat == MrzFormat.TD1
          ? DocumentType.travelDocument1
          : DocumentType.travelDocument2;

  // Raw lines
  String line1;
  String line2;
  String? line3;

  /// ICAO MRZ document type (e.g., 'P' passport, 'V' visa)
  String documentType;
  String documentCode;

  /// Best-known MRZ format (TD3 for passports, MRV-A/MRV-B for visas)
  String? mrzFormat;

  /// For passports, this is the issuing country (same as before).
  /// For visas, this mirrors the issuing state (so old code keeps working).
  String countryCode;

  /// Explicit issuing state (for visas). For passports, equals [countryCode].
  String issuingState;

  /// Unified document number (passport/visa number).
  /// Kept `passportNumber` for backward compatibility.
  String documentNumber;

  /// Back-compat alias of [documentNumber]. Will equal [documentNumber].
  String get passportNumber => documentNumber;

  set passportNumber(String v) => documentNumber = v;

  String lastName;
  String firstName;
  String nationality;
  DateTime? birthDate;
  DateTime? expiryDate;
  DateTime? issueDate;
  String sex;
  String? numberCheck;
  String? bDataCheck;
  String? eDataCheck;
  String? birthStr;
  String? expStr;

  /// Passport’s optional/personal number (TD3). For visas this will mirror [optionalData].
  String personalNumber;

  /// Visa’s optional tail (line 2 after expiry check). For passports mirrors [personalNumber].
  String optionalData;

  OcrMrzValidation valid;
  CheckDigits checkDigits;
  OcrData ocrData;
  String format;

  /// The duration from the start of the session until the result was found.
  /// This is a runtime value and not part of the JSON serialization.
  Duration? scanDuration;

  // Convenience
  // bool get isVisa => documentType == 'V';
  bool get isVisa => documentCode.startsWith("V");

  // bool get isPassport => documentType == 'P';
  bool get isPassport => documentCode.startsWith("P");

  String get getFullName => "${firstName} ${lastName}";

  String get typeName {
    switch (format) {
      case MrzFormat.TD3:
        return "Passport";
      case MrzFormat.MRV_A:
        return "Visa";
      case MrzFormat.MRV_B:
        return "Visa";
      case MrzFormat.TD1:
        return "ID Card (TD1)";
      case MrzFormat.TD2:
        return "ID Card (TD2)";
      case MrzFormat.unknown:
      default:
        return "Unknown Document";
    }
  }

  OcrMrzResult({
    required this.line1,
    required this.line2,
    required this.format,
    required this.documentCode,
    this.line3,
    required this.documentType,
    required this.mrzFormat,
    required this.countryCode,
    required this.issuingState,
    this.issueDate,
    required this.lastName,
    required this.firstName,
    required this.documentNumber,
    required this.nationality,
    required this.birthDate,
    required this.expiryDate,
    required this.sex,
    required this.personalNumber,
    required this.optionalData,
    required this.valid,
    required this.checkDigits,
    required this.ocrData,
    this.scanDuration,
    this.bDataCheck,
    this.eDataCheck,
    this.numberCheck,
    this.birthStr,
    this.expStr,
  });

  /// Robust factory that accepts both the old (passport-only) JSON and the new visa-aware JSON.
  factory OcrMrzResult.fromJson(Map<String, dynamic> json) {
    final docType = (json["documentType"] ?? '').toString();
    final formatStr = (json["mrzFormat"] ?? '').toString().toUpperCase();
    String fmt;
    switch (formatStr) {
      case 'TD3':
        fmt = "td3";
        break;
      case 'MRV-A':
      case 'MRV_A':
        fmt = "mrva";
        break;
      case 'MRV-B':
      case 'MRV_B':
        fmt = "mrvb";
        break;
      default:
        // Infer if not provided
        if (docType == 'V') {
          // If lines are 44 => MRV-A, 36 => MRV-B, else unknown
          final l2 = (json["line2"] ?? '') as String? ?? '';
          fmt = l2.length == 44 ? "mrva" : (l2.length == 36 ? "mrvb" : "unknown");
        } else if (docType == 'P') {
          fmt = "td3";
        } else {
          fmt = "unknown";
        }
    }

    // issuing state vs country
    final issuing = (json["issuingState"] ?? json["countryCode"] ?? '').toString();
    final country = (json["countryCode"] ?? issuing).toString();
    final documentCode = (json["documentCode"] ?? json["documentType"]).toString();

    // document number: accept new key, fallback to old "passportNumber"
    final docNo = (json["documentNumber"] ?? json["passportNumber"] ?? '').toString();

    // optional/personal mirroring
    final opt = (json["optionalData"] ?? json["personalNumber"] ?? '').toString();
    final personal = (json["personalNumber"] ?? json["optionalData"] ?? '').toString();

    return OcrMrzResult(
      line1: json["line1"],
      line2: json["line2"],
      line3: json["line3"],
      documentCode: json["documentCode"],
      documentType: docType,
      mrzFormat: fmt,
      countryCode: country,
      issuingState: issuing,
      lastName: json["lastName"],
      firstName: json["firstName"],
      documentNumber: docNo,
      nationality: json["nationality"],
      birthDate: dateFromIsoIgnoreTime(json["birthDate"]),
      expiryDate: dateFromIsoIgnoreTime(json["expiryDate"]),
      issueDate: dateFromIsoIgnoreTime(json["issueDate"]),
      sex: json["sex"],
      personalNumber: personal,
      optionalData: opt,
      valid: OcrMrzValidation.fromJson(json["valid"] ?? const {}),
      checkDigits: CheckDigits.fromJson(json["checkDigits"] ?? const {}),
      ocrData: OcrData.fromJson(json["ocrData"]),
      format: json["format"] ?? 'unknown',
    );
  }

  List<String> get mrzLines => line3 != null ? [line1, line2, line3!] : [line1, line2];

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      "line1": line1,
      "line2": line2,
      "line3": line3,
      "documentCode": documentCode,
      "documentType": documentType,
      "mrzFormat": mrzFormat,
      "format": format.toString().split('.').last,
      // Keep both for compatibility
      "issuingState": issuingState,
      "countryCode": countryCode,
      // Unified + legacy
      "documentNumber": documentNumber,
      "passportNumber": documentNumber,
      "lastName": lastName,
      "firstName": firstName,
      "nationality": nationality,
      "birthDate": dateAsUtcIso(birthDate),
      "expiryDate": dateAsUtcIso(expiryDate),
      "issueDate": dateAsUtcIso(issueDate),
      "sex": sex,
      // Mirror both ways to keep old consumers happy
      "personalNumber": personalNumber.isNotEmpty ? personalNumber : optionalData,
      "optionalData": optionalData.isNotEmpty ? optionalData : personalNumber,
      "valid": valid.toJson(),
      "checkDigits": checkDigits.toJson(),
      "ocrData": ocrData.toJson(),
    };
    return map;
  }

  static String _formatToString(MrzFormat f) {
    switch (f) {
      case MrzFormat.TD3:
        return "TD3";
      case MrzFormat.MRV_A:
        return "MRV-A";
      case MrzFormat.MRV_B:
        return "MRV-B";
      default:
        return "unknown";
    }
  }

  OcrMrzDocumentDetail? toDocument() {
    OcrMrzDocumentDetail d = OcrMrzDocumentDetail();

    if (!valid.birthDateValid || !valid.expiryDateValid || !valid.docNumberValid || !valid.countryValid) {
      return null;
    }

    final constData = ConstData.offline();

    final nat = constData!.getLocationWithCode(nationality);
    final issueCountry = constData!.getLocationWithCode(countryCode);
    String short =
        documentCode.startsWith("P")
            ? "P"
            : documentCode.startsWith("V")
            ? "V"
            : "P";

    OcrMrzDocumentDetail documentDetail = OcrMrzDocumentDetail(
      shortType: short,
      documentExpiryDate: expiryDate,
      documentIssueCountry: issueCountry,
      documentCode: null,
      fullName: "$firstName $lastName",
      documentNumber: documentNumber,
      nationality: nat,
      mrz: mrzLines.join("\n"),
      birthDate: birthDate,
      ocrText: ocrData.text,
      sex: sex,
      docCode: documentCode,
      verifiedDocNum: false,
    );
    return documentDetail;
  }

  OcrMrzResult fixLines() {
    String line1 = "${documentCode.padRight(2, "<")}${issuingState.padRight(3, "<")}${"${lastName}<<${firstName}"}".padRight(44, "<");
    String line2 = "${documentNumber.padRight(9, "<")}${numberCheck ?? "<"}${nationality}${birthStr ?? "<<<<<<"}${bDataCheck ?? "<"}${sex.padRight(1, "<")}${expStr ?? "<<<<<<"}${eDataCheck ?? "<"}"
        .padRight(44, "<");

    var fixed = this;
    fixed.line1 = line1;
    fixed.line2 = line2;
    return this;
  }
}

class CheckDigits {
  /// Unified doc number check (passport/visa).
  bool document;

  bool birth;
  bool expiry;
  bool optional;

  /// Passports have a composite final check; visas do NOT.
  /// If null => not applicable.
  bool? finalComposite;

  CheckDigits({required this.document, required this.birth, required this.expiry, required this.optional, this.finalComposite});

  factory CheckDigits.fromJson(Map<String, dynamic> json) => CheckDigits(
    // accept both "document" and legacy "passport"
    document: (json["document"] ?? json["passport"] ?? false) as bool,
    birth: json["birth"] ?? false,
    expiry: json["expiry"] ?? false,
    optional: json["optional"] ?? false,
    finalComposite: json.containsKey("final") ? (json["final"] as bool?) : (json.containsKey("finalComposite") ? json["finalComposite"] as bool? : null),
  );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{"document": document, "birth": birth, "expiry": expiry, "optional": optional};
    // Keep legacy "passport" key in sync for old readers
    map["passport"] = document;

    if (finalComposite != null) {
      map["final"] = finalComposite;
      map["finalComposite"] = finalComposite;
    }
    return map;
  }
}

class OcrMrzValidation {
  bool docNumberValid;
  bool docCodeValid;
  bool birthDateValid;
  bool expiryDateValid;
  bool personalNumberValid;

  /// For visas, there is no final composite check.
  /// Use [hasFinalCheck]=false so UIs can ignore [finalCheckValid].
  bool finalCheckValid;

  /// Indicates if a final composite check exists for this document type.
  bool hasFinalCheck;

  bool nameValid;
  bool sexValid;
  bool linesLengthValid;
  bool countryValid;
  bool nationalityValid;

  OcrMrzValidation({
    this.sexValid = false,
    this.docNumberValid = false,
    this.docCodeValid = false,
    this.birthDateValid = false,
    this.expiryDateValid = false,
    this.personalNumberValid = false,
    this.finalCheckValid = false,
    this.hasFinalCheck = false,
    this.nameValid = false,
    this.linesLengthValid = false,
    this.countryValid = false,
    this.nationalityValid = false,
  });

  factory OcrMrzValidation.fromJson(Map<String, dynamic> json) => OcrMrzValidation(
    docNumberValid: json["docNumberValid"] ?? false,
    docCodeValid: json["docCodeValid"] ?? false,
    sexValid: json["sexValid"] ?? false,
    birthDateValid: json["birthDateValid"] ?? false,
    expiryDateValid: json["expiryDateValid"] ?? false,
    personalNumberValid: json["personalNumberValid"] ?? false,
    finalCheckValid: json["finalCheckValid"] ?? false,
    hasFinalCheck: json["hasFinalCheck"] ?? true,
    nameValid: json["nameValid"] ?? false,
    linesLengthValid: json["linesLengthValid"] ?? false,
    countryValid: json["countryValid"] ?? false,
    nationalityValid: json["nationalityValid"] ?? false,
  );

  Map<String, dynamic> toJson() => {
    "docNumberValid": docNumberValid,
    "sexValid": sexValid,
    "birthDateValid": birthDateValid,
    "docCodeValid": docCodeValid,
    "expiryDateValid": expiryDateValid,
    "personalNumberValid": personalNumberValid,
    "finalCheckValid": finalCheckValid,
    "hasFinalCheck": hasFinalCheck,
    "nameValid": nameValid,
    "linesLengthValid": linesLengthValid,
    "countryValid": countryValid,
    "nationalityValid": nationalityValid,
  };

  @override
  String toString() {
    final finalLabel = hasFinalCheck ? "Final ${finalCheckValid ? '✅' : '❌'}" : "Final N/A";
    return "Num ${docNumberValid ? '✅' : '❌'} "
        "Code ${docCodeValid ? '✅' : '❌'} "
        "Bth ${birthDateValid ? '✅' : '❌'} "
        "Exp ${expiryDateValid ? '✅' : '❌'} "
        // "Personal ${personalNumberValid ? '✅' : '❌'}  "
        "Iss ${countryValid ? '✅' : '❌'} "
        "Nat ${nationalityValid ? '✅' : '❌'} "
        "Sex ${sexValid ? '✅' : '❌'} ";
    // "$finalLabel";
  }
}

class OcrMrzCountValidation {
  int docNumberValidCount;
  int docCodeValidCount;
  int birthDateValidCount;
  int expiryDateValidCount;
  int personalNumberValidCount;
  int nameValidCount;
  int sexValidCount;
  int countryValidCount;
  int nationalityValidCount;

  OcrMrzCountValidation({
    this.docNumberValidCount = 1,
    this.docCodeValidCount = 1,
    this.birthDateValidCount = 1,
    this.expiryDateValidCount = 1,
    this.personalNumberValidCount = 1,
    this.nameValidCount = 1,
    this.sexValidCount = 1,
    this.countryValidCount = 1,
    this.nationalityValidCount = 1,
  });

  factory OcrMrzCountValidation.fromJson(Map<String, dynamic> json) => OcrMrzCountValidation(
    docNumberValidCount: json["docNumberValidCount"] ?? 1,
    docCodeValidCount: json["docCodeValidCount"] ?? 1,
    birthDateValidCount: json["birthDateValidCount"] ?? 1,
    expiryDateValidCount: json["expiryDateValidCount"] ?? 1,
    personalNumberValidCount: json["personalNumberValidCount"] ?? 1,
    nameValidCount: json["nameValidCount"] ?? 1,
    sexValidCount: json["sexValidCount"] ?? 1,
    countryValidCount: json["countryValidCount"] ?? 1,
    nationalityValidCount: json["nationalityValidCount"] ?? 1,
  );

  Map<String, dynamic> toJson() => {
    "docNumberValidCount": docNumberValidCount,
    "docCodeValidCount": docCodeValidCount,
    "birthDateValidCount": birthDateValidCount,
    "expiryDateValidCount": expiryDateValidCount,
    "personalNumberValidCount": personalNumberValidCount,
    "nameValidCount": nameValidCount,
    "sexValidCount": sexValidCount,
    "countryValidCount": countryValidCount,
    "nationalityValidCount": nationalityValidCount,
  };
}

/// Write as UTC midnight ISO (e.g. 2025-09-06T00:00:00.000Z)
String? dateAsUtcIso(DateTime? d) {
  if (d == null) return null;
  return DateTime.utc(d.year, d.month, d.day).toIso8601String();
}

/// Read from ISO but keep only the calendar parts (avoid TZ shifts)
DateTime? dateFromIsoIgnoreTime(String? iso) {
  if (iso == null) {
    return null;
  }
  final dt = DateTime.parse(iso); // may be UTC or local depending on 'Z'
  final utc = dt.toUtc(); // normalize to UTC
  return DateTime(utc.year, utc.month, utc.day); // local date with same Y/M/D
}
