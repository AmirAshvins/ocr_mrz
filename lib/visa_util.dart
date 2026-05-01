import 'dart:convert';
import 'dart:developer';

import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';
import 'package:ocr_mrz/doc_code_validator.dart';
import 'package:ocr_mrz/mrz_result_class_fix.dart'; // reuse your OcrMrzResult model or make a Visa variant if you prefer
import 'package:ocr_mrz/name_validation_data_class.dart';

import 'ocr_mrz_settings_class.dart';
import 'orc_mrz_log_class.dart';
import 'passport_util.dart';
import 'travel_doc_util.dart'; // reuse your flags
// Reuse: isValidMrzCountry(String), _computeMrzCheckDigit(String), validateNames(...), extractWords(...)

/// Public entry — tries MRV-A then MRV-B. Returns a JSON-ish map compatible with your OcrMrzResult.fromJson()
Map<String, dynamic>? tryParseVisaMrzFromOcrLines(
    OcrData ocrData,
    OcrMrzSetting? setting,
    List<NameValidationData>? nameValidations,
     void Function(OcrMrzLog log)? mrzLogger
    ) {
  final rawAllLines = ocrData.lines.map((e) => e.text).toList();
  final normalized = rawAllLines.map(_normalizeVisaLine).toList();
  final s = setting ?? OcrMrzSetting();

  // Try MRV-A (44) then MRV-B (36). First success wins.
  final res =  _findVisaPairAndParse(
    normalized: normalized,
    rawAllLines: rawAllLines,
    targetLen: 44,
    validateSettings: s,
    nameValidations: nameValidations,
    ocr: ocrData,
    mrzLogger: mrzLogger
  )
      ?? _findVisaPairAndParse(
        normalized: normalized,
        rawAllLines: rawAllLines,
        targetLen: 36,
        validateSettings: s,
        nameValidations: nameValidations,
        ocr: ocrData,
        mrzLogger: mrzLogger
      );

  return res;
}

Map<String, dynamic>? _findVisaPairAndParse({
  required List<String> normalized,
  required List<String> rawAllLines,
  required int targetLen,
  required OcrMrzSetting validateSettings,
  required List<NameValidationData>? nameValidations,
  required OcrData ocr,
  required void Function(OcrMrzLog log)? mrzLogger
}) {
  // Keep enforced length + original indices so we can form pairs reliably.
  final enforced = <int, String>{};
  for (var i = 0; i < normalized.length; i++) {
    final line = _enforceLen(normalized[i], targetLen);
    if (line.length == targetLen) {
      enforced[i] = line;
    }
  }
  if (enforced.isEmpty) return null;

  // Candidate line-1: must start with V and contain << (names separator) to reduce false positives.
  final l1Candidates = enforced.entries
      .where((e) => e.value.startsWith('V') && e.value.contains('<'))
      .toList();

  if (l1Candidates.isEmpty) return null;

  // Try nearest neighbors first: forward (i+1..i+3), then backward (i-1..i-3).
  const window = 3;

  for (final c in l1Candidates.reversed) {
    final i = c.key;
    final rawL1 = c.value;
    final line1 = _repairVisaLine1(rawL1, targetLen);

    // Search forward
    for (var j = i + 1; j <= i + window; j++) {
      final res = _tryVisaPairIndices(
        i: i,
        j: j,
        enforced: enforced,
        line1: line1,
        targetLen: targetLen,
        rawAllLines: rawAllLines,
        validateSettings: validateSettings,
        nameValidations: nameValidations,
        ocr: ocr,
        mrzLogger: mrzLogger
      );
      if (res != null) return res;
    }

    // Fallback: search backward in case OCR order is flipped
    for (var j = i - 1; j >= i - window; j--) {
      final res = _tryVisaPairIndices(
        i: i,
        j: j,
        enforced: enforced,
        line1: line1,
        targetLen: targetLen,
        rawAllLines: rawAllLines,
        validateSettings: validateSettings,
        nameValidations: nameValidations,
        ocr: ocr,
        mrzLogger: mrzLogger
      );
      if (res != null) return res;
    }
  }

  return null;
}

Map<String, dynamic>? _tryVisaPairIndices({
  required int i,
  required int j,
  required Map<int, String> enforced,
  required String line1,
  required int targetLen,
  required List<String> rawAllLines,
  required OcrMrzSetting validateSettings,
  required List<NameValidationData>? nameValidations,
  required OcrData ocr,
  required void Function(OcrMrzLog log)? mrzLogger
}) {
  if (!enforced.containsKey(j)) {
    final rawAllLines = ocr.lines.map((e) => e.text).toList();
    final rawMrzLines = rawAllLines.where((a)=>a.length>35 && a.contains("<")).toList();
    mrzLogger?.call(OcrMrzLog(rawText: ocr.text, rawMrzLines: rawMrzLines, fixedMrzLines: [line1],validation:OcrMrzValidation(),extractedData: {}));
    return null;
  }
  var candidateL2 = enforced[j]!;

  // Line-2 should NOT start with 'V' (it begins with doc number)
  if (candidateL2.startsWith('V')) {
    final rawAllLines = ocr.lines.map((e) => e.text).toList();
    final rawMrzLines = rawAllLines.where((a)=>a.length>35 && a.contains("<")).toList();
    mrzLogger?.call(OcrMrzLog(rawText: ocr.text, rawMrzLines: rawMrzLines, fixedMrzLines: [line1],validation:OcrMrzValidation(),extractedData: {}));

    return null;
  }

  // Repair and sanity-check line 2 BEFORE parsing (reduces false positives)
  final line2 = _repairVisaLine2(candidateL2, targetLen);
  if (!_looksLikeVisaLine2(line2)) {
    final rawAllLines = ocr.lines.map((e) => e.text).toList();
    final rawMrzLines = rawAllLines.where((a)=>a.length>35 && a.contains("<")).toList();
    mrzLogger?.call(OcrMrzLog(rawText: ocr.text, rawMrzLines: rawMrzLines, fixedMrzLines: [line1,line2],validation:OcrMrzValidation(),extractedData: {}));
    return null;
  }

  // Build otherLines (exclude the two MRZ lines by index)
  final otherLines = <String>[];
  for (var k = 0; k < rawAllLines.length; k++) {
    if (k != i && k != j) otherLines.add(rawAllLines[k]);
  }

  // Parse (common routine validates check digits, names, countries, etc.)
  final parsed = _parseVisaCommon(
    line1: line1,
    line2: line2,
    len: targetLen,
    otherLines: otherLines,
    validateSettings: validateSettings,
    nameValidations: nameValidations,
    ocr: ocr,
    mrzLogger: mrzLogger
  );

  if (parsed != null) {
    parsed['ocrData'] = ocr.toJson(); // for debugging parity with passport path
    return parsed;
  }
  return null;
}

bool _looksLikeVisaLine2(String l2) {
  if (l2.length < 28) return false;

  // YYMMDD positions are fixed for MRV-A/MRV-B; sex at pos 20.
  final birth = l2.substring(13, 19);
  final birthCheck = l2[19];
  final sex = l2[20];
  final expiry = l2.substring(21, 27);
  final expiryCheck = l2[27];

  // Coarse checks first
  final birthDigits = RegExp(r'^\d{6}$').hasMatch(birth);
  final expiryDigits = RegExp(r'^\d{6}$').hasMatch(expiry);
  final sexOk = (sex == 'M' || sex == 'F' || sex == '<');
  if (!(birthDigits && expiryDigits && sexOk)) return false;

  // Quick check-digit validation (fast and cheap)
  final birthOk = _computeMrzCheckDigit(birth) == birthCheck;
  final expiryOk = _computeMrzCheckDigit(expiry) == expiryCheck;
  return birthOk && expiryOk;
}



typedef _VisaParser = Map<String, dynamic>? Function({required String line1, required String line2, required List<String> otherLines, required OcrMrzSetting validateSettings, required List<NameValidationData>? nameValidations});

Map<String, dynamic>? _tryPairAndParse(List<String> normalizedCandidates, List<String> rawAllLines, int targetLen, _VisaParser parser, OcrMrzSetting? setting, List<NameValidationData>? nameValidations, OcrData ocr) {
  // Keep only lines of the right length and that start with V
  final mrz = normalizedCandidates.map((l) => _enforceLen(l, targetLen)).where((l) => l.length == targetLen && l.startsWith('V')).toList();
  // log("mrz lines leng ${mrz.length}");
  if (mrz.length < 2) return null;
    // log("mrz lines leng ${mrz.length}");
  // Use the last valid consecutive pair (like you did for passports)
  final line1 = mrz[mrz.length - 2];
  final line2 = mrz[mrz.length - 1];
  final otherLines = rawAllLines.where((a) => a != line1 && a != line2).toList();

  final validateSettings = setting ?? OcrMrzSetting();

  return parser(line1: _repairVisaLine1(line1, targetLen), line2: _repairVisaLine2(line2, targetLen), otherLines: otherLines, validateSettings: validateSettings, nameValidations: nameValidations)?.let((res) {
    // Attach raw OCR for debugging like your passport code
    res['ocrData'] = ocr.toJson();
    log(jsonEncode(ocr.toJson()));
    return res;
  });
}

extension<T> on T {
  R? let<R>(R Function(T it) block) => block(this);
}

/// Normalization tailored for visas; keeps your spirit but without forcing to 44 by default.
String _normalizeVisaLine(String line) {
  final map = {'«': '<', '|': '<', '\\': '<', '/': '<', '“': '<', '”': '<', '’': '<', '‘': '<', ' ': '<'};

  String normalized = line.toUpperCase().split('').map((c) => map[c] ?? c).where((c) => RegExp(r'[A-Z0-9<]').hasMatch(c)).join();

  // Convert frequent OCR bursts like KK or XX to single filler, but only when surrounded by fillers.
  normalized = normalized.replaceAll(RegExp(r'(<)[KX]{2,}(<)'), '<<<');

  return normalized;
}

String _enforceLen(String s, int len) {
  if (s.length == len) return s;
  if (s.length > len) return s.substring(0, len);
  return s.padRight(len, '<');
}

String _repairVisaLine1(String line1, int len) {
  // MRV line1: V + type + issuingState + names with << between primary/secondary
  String l = _enforceLen(line1, len);
  if (!l.startsWith('V')) l = 'V' + l.substring(1); // force
  // Make sure positions 2–4 are alpha (issuing state), fix common OCR 0/1/5/8/6 into letters
  final start = l.substring(0, 5);
  final issuing =
      l.substring(2, 5).split('').map((c) {
        switch (c) {
          case '0':
            return 'O';
          case '1':
            return 'I';
          case '5':
            return 'S';
          case '8':
            return 'B';
          case '6':
            return 'G';
          default:
            return c;
        }
      }).join();
  final rest = l.substring(5);
  return start.substring(0, 2) + issuing + rest;
}

String _repairVisaLine2(String line2, int len) {
  // Enforce charset and length
  String l = _normalizeVisaLine(line2);
  l = _enforceLen(l, len);

  // Hard fixes by position (numbers only in dates/checks)
  // birth YYMMDD at 13..18 (0-based), expiry at 21..26 for MRV-A; MRV-B uses same indices relative to 36?
  // Field positions are identical; only total length differs.
  // Replace common letter-as-digit confusions in numeric fields:
  List<int> numericPositions = [
    // doc number can be alnum, so skip 0..8 conversion
    9, // doc check
    13, 14, 15, 16, 17, 18, // birth
    19, // birth check
    21, 22, 23, 24, 25, 26, // expiry
    27, // expiry check
  ];

  final buf = l.split('');
  String asDigit(String c) {
    switch (c) {
      case 'O':
        return '0';
      case 'Q':
        return '0';
      case 'I':
        return '1';
      case 'L':
        return '1';
      case 'Z':
        return '2';
      case 'S':
        return '5';
      case 'B':
        return '8';
      case 'G':
        return '6';
      default:
        return c;
    }
  }

  for (final i in numericPositions) {
    if (i >= 0 && i < buf.length) buf[i] = asDigit(buf[i]);
  }

  // Sex field at 20: coerce to M/F/< if misread
  if (buf.length > 20) {
    final s = buf[20];
    buf[20] = (s == 'M' || s == 'F' || s == '<') ? s : '<';
  }

  return buf.join();
}

/// Shared parse for both MRV-A (len=44) and MRV-B (len=36)
Map<String, dynamic>? _parseVisaCommon({
  required String line1,
  required String line2,
  required int len,
  required List<String> otherLines,
  required OcrMrzSetting validateSettings,
  required List<NameValidationData>? nameValidations,
  required OcrData ocr,
  required void Function(OcrMrzLog log)? mrzLogger
}) {
  try {
    log("_parseVisaCommon");
    // --- Line 1 ---
    final documentType = line1.substring(0, 1); // 'V'
    final documentCode = line1.substring(0, 2); // 'V'
    final visaType = line1.substring(1, 2); // optional category by issuer

    final issuingState = fixAlphaOnlyField(line1.substring(2, 5)); // country/org
    final nameField = line1.substring(5);

    final nameParts = nameField.split('<<');
    String lastName = nameParts.isNotEmpty ? nameParts[0].replaceAll('<', ' ').trim() : '';
    String firstName = nameParts.length > 1 ? nameParts[1].replaceAll('<', ' ').trim() : '';

    firstName = _cleanMrzVisaName(firstName);
    lastName = _cleanMrzVisaName(lastName);


    // --- Line 2 ---
    final docNumber = line2.substring(0, 9);
    final docCheck = line2.substring(9, 10);
    final nationality =fixAlphaOnlyField(line2.substring(10, 13));
    final birth = line2.substring(13, 19);
    final birthCheck = line2.substring(19, 20);
    final sex = line2.substring(20, 21);
    final expiry = line2.substring(21, 27);
    final expiryCheck = line2.substring(27, 28);
    final optional = line2.substring(28, len); // no final composite check for visas

    // Validate check digits (no composite)
    final validDoc = _computeMrzCheckDigit(docNumber) == docCheck;
    final validBirth = RegExp(r'^\d{6}$').hasMatch(birth) && _computeMrzCheckDigit(birth) == birthCheck;
    final validExpiry = RegExp(r'^\d{6}$').hasMatch(expiry) && _computeMrzCheckDigit(expiry) == expiryCheck;

    // Name/country validations (reuse your switches)
    final namesOk =
        validateSettings.validateNames
            ? (validateNames(firstName, lastName, otherLines) || (nameValidations?.any((a) => a.firstName.toLowerCase() == firstName.toLowerCase() && a.lastName.toLowerCase() == lastName.toLowerCase()) ?? false))
            : true;

    final issuingOk = validateSettings.validateCountry ? isValidMrzCountry(issuingState) : true;
    final nationalityOk = validateSettings.validateNationality ? isValidMrzCountry(nationality) : true;
    final birthOk = !validateSettings.validateBirthDateValid || validBirth;
    final expiryOk = !validateSettings.validateExpiryDateValid || validExpiry;
    final docOk = !validateSettings.validateDocNumberValid || validDoc;
    final docCodeValid = !validateSettings.validateDocNumberValid || DocumentCodeHelper.isValid(documentCode);


    // if (!(namesOk && issuingOk && nationalityOk && birthOk && expiryOk && docOk)) return null;


    final validation = validateMrzLineVisa(line1: line1, line2: line2, setting: validateSettings, otherLines: otherLines, firstName: firstName, lastName: lastName, country: issuingState, nationality: nationality, personalNumber: '', nameValidations: nameValidations, issuing: issuingState);
    final resultMap =  {
      // Raw
      'line1': line1,
      'line2': line2,
      'documentCode': documentCode,

      // Types & format
      'documentType': documentType,                   // 'V'
      'mrzFormat': (len == 44) ? 'MRV-A' : 'MRV-B',   // <-- new

      // Issuer
      'issuingState': issuingState,                   // new explicit field
      'countryCode': issuingState,                    // mirror for back-compat

      // Names
      'lastName': lastName,
      'firstName': firstName,

      // Numbers / nationality
      'documentNumber': docNumber,                    // unified key
      'passportNumber': docNumber,                    // legacy mirror
      'nationality': nationality,

      // Dates / sex
      'birthDate': _parseMrzVisaDate(birth)?.toIso8601String(),
      'expiryDate': _parseMrzVisaDate(expiry)?.toIso8601String(),
      'sex': sex,

      // Optional tail (MRV) + legacy mirror
      'optionalData': optional,
      'personalNumber': optional,                     // mirror for old readers

      // Validations
      'valid': _visaValidationMap(
        docOk: validDoc,
        documentCode:docCodeValid,
        birthOk: validBirth,
        expiryOk: validExpiry,
        namesOk: namesOk,
        issuingOk: issuingOk,
        nationalityOk: nationalityOk,
        lineLen: len,
      ),

      // Check digits (no final for visas)
      'checkDigits': _visaCheckDigitsMap(
        docOk: validDoc,
        birthOk: validBirth,
        expiryOk: validExpiry,
      ),
      'format': (line1.length == 44)
          ? MrzFormat.MRV_A.toString().split('.').last
          : MrzFormat.MRV_B.toString().split('.').last
    };

    final rawAllLines = ocr.lines.map((e) => e.text).toList();
    final rawMrzLines = rawAllLines.where((a)=>a.length>35 && a.contains("<<")).toList();
    mrzLogger?.call(OcrMrzLog(rawText: ocr.text, rawMrzLines: rawMrzLines, fixedMrzLines: [line1,line2],validation:validation,extractedData: resultMap));

    if (firstName.isEmpty && lastName.isEmpty) return null;

    log(validation.toString());
    // Build result similar to your passport result
    // return {
    //   'format': len == 44 ? 'MRV-A' : 'MRV-B',
    //   'line1': line1,
    //   'line2': line2,
    //   'documentType': documentType, // 'V'
    //   'visaType': visaType, // issuer-defined
    //   'issuingState': issuingState,
    //   'lastName': lastName,
    //   'firstName': firstName,
    //   'documentNumber': docNumber,
    //   'nationality': nationality,
    //   'birthDate': _parseMrzVisaDate(birth)?.toIso8601String(),
    //   'expiryDate': _parseMrzVisaDate(expiry)?.toIso8601String(),
    //   'sex': sex,
    //   'optionalData': optional,
    //   'checkDigits': {
    //     'document': validDoc,
    //     'birth': validBirth,
    //     'expiry': validExpiry,
    //     // no 'final' for visa MRZ
    //   },
    // };


    return resultMap;

  } catch (_) {
    return null;
  }
}

OcrMrzValidation validateMrzLineVisa({
  required String line1,
  required String line2,
  required OcrMrzSetting setting,
  required List<String> otherLines,
  required String firstName,
  required String lastName,
  required String country,
  required String nationality,
  required String issuing,
  required String personalNumber,
  required List<NameValidationData>? nameValidations,
}) {
  OcrMrzValidation validation = OcrMrzValidation();
  try {
    final docNumber = line2.substring(0, 9);
    final docCode = line1.substring(0, 2);
    final docCheck = line2.substring(9, 10);
    final nationality =fixAlphaOnlyField(line2.substring(10, 13));
    final birth = line2.substring(13, 19);
    final birthCheck = line2.substring(19, 20);
    final sex = line2.substring(20, 21);
    final expiry = line2.substring(21, 27);
    final expiryCheck = line2.substring(27, 28);
    final optional = line2.substring(28, line2.length); // no final composite check for visas

    // Validate check digits (no composite)
    final validDoc = _computeMrzCheckDigit(docNumber) == docCheck;
    final validBirth = RegExp(r'^\d{6}$').hasMatch(birth) && _computeMrzCheckDigit(birth) == birthCheck;
    final validExpiry = RegExp(r'^\d{6}$').hasMatch(expiry) && _computeMrzCheckDigit(expiry) == expiryCheck;

    // Name/country validations (reuse your switches)
    var namesOk =
    validation.nameValid
        ? (validateNames(firstName, lastName, otherLines) || (nameValidations?.any((a) => a.firstName.toLowerCase() == firstName.toLowerCase() && a.lastName.toLowerCase() == lastName.toLowerCase()) ?? false))
        : true;

    final issuingOk = validation.countryValid ? isValidMrzCountry(issuing) : true;
    final nationalityOk = validation.nationalityValid ? isValidMrzCountry(nationality) : true;
    final birthOk = !validation.birthDateValid || validBirth;
    final expiryOk = !validation.expiryDateValid || validExpiry;
    final docOk = !validation.docNumberValid || validDoc;

    validation.docCodeValid = DocumentCodeHelper.isValid(docCode);
    validation.docNumberValid = docOk;
    validation.birthDateValid = birthOk;
    validation.expiryDateValid = expiryOk;

    // String personalNumber = personalNumber;
    String personalCheck = line2[42];
    final isPersonalValid = personalNumber.replaceAll('<', '').isEmpty
        ? (personalCheck == '0' || personalCheck == '<')
        : (_computeMrzCheckDigit(personalNumber) == personalCheck);
    validation.personalNumberValid = isPersonalValid;


    // bool isFinalCheckValid = _computeMrzCheckDigit(docNumber + docCheck + birth + birthCheck + expiry + expiryCheck + personalNumber + personalCheck) == finalCheck;
    validation.finalCheckValid = true;

    validation.nameValid = namesOk;
    if(!namesOk && nameValidations!=null){
      if(nameValidations.any((a)=>a.firstName.toLowerCase() == firstName.toLowerCase() && a.lastName.toLowerCase()==lastName.toLowerCase())){
        namesOk = true;
        validation.nameValid = true;
      }
    }


    validation.countryValid = issuingOk;

    validation.nationalityValid = nationalityOk;

    return validation;
  } catch (e) {
    return validation;
  }
}

// Map<String, dynamic>? _parseMrvA({required String line1, required String line2, required List<String> otherLines, required OcrMrzSetting validateSettings, required List<NameValidationData>? nameValidations}) {
//   final l1 = _enforceLen(line1, 44);
//   final l2 = _enforceLen(line2, 44);
//   return _parseVisaCommon(line1: l1, line2: l2, len: 44, otherLines: otherLines, validateSettings: validateSettings, nameValidations: nameValidations);
// }
//
// Map<String, dynamic>? _parseMrvB({required String line1, required String line2, required List<String> otherLines, required OcrMrzSetting validateSettings, required List<NameValidationData>? nameValidations}) {
//   final l1 = _enforceLen(line1, 36);
//   final l2 = _enforceLen(line2, 36);
//   return _parseVisaCommon(line1: l1, line2: l2, len: 36, otherLines: otherLines, validateSettings: validateSettings, nameValidations: nameValidations);
// }

/// Slightly different cleanup for names (keep your approach, tuned for visas)
String _cleanMrzVisaName(String input) =>
    input
        .replaceAll('0', 'O')
        .replaceAll('1', 'I')
        .replaceAll('5', 'S')
        .replaceAll(RegExp(r'[2-9]'), '') // drop stray digits
        .replaceAll('<', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

DateTime? _parseMrzVisaDate(String yymmdd) {
  if (!RegExp(r'^\d{6}$').hasMatch(yymmdd)) return null;
  final yy = int.parse(yymmdd.substring(0, 2));
  final mm = int.parse(yymmdd.substring(2, 4));
  final dd = int.parse(yymmdd.substring(4, 6));
  final nowYY = DateTime.now().year % 100;

  // Same heuristic you used: future-leaning for small YY, else 1900s
  final year = yy <= nowYY + 10 ? 2000 + yy : 1900 + yy;
  try {
    return DateTime(year, mm, dd);
  } catch (_) {
    return null;
  }
}

/// Convenience hook mirroring your passport flow
// void handleOcrVisa(
//   OcrData ocr,
//   void Function(OcrMrzResult res) onFoundVisaMrz, // or create OcrVisaResult if you prefer
//   OcrMrzSetting? setting,
//   List<NameValidationData>? nameValidations,
// ) {
//   try {
//     final m = tryParseVisaMrzFromOcrLines(ocr, setting, nameValidations);
//     if (m != null) {
//       log("✅ Valid Visa MRZ (${m['format']}):");
//       final r = OcrMrzResult.fromJson(m); // works if your model is generic enough; else make a Visa variant
//       log("${r.line1}\n${r.line2}");
//       onFoundVisaMrz(r);
//     }
//   } catch (e, st) {
//     log(e.toString());
//     log(st.toString());
//   }
// }

String _computeMrzCheckDigit(String input) {
  final weights = [7, 3, 1];
  int sum = 0;

  for (int i = 0; i < input.length; i++) {
    final c = input[i];
    int v;
    if (RegExp(r'[0-9]').hasMatch(c)) {
      v = int.parse(c); // digits are their own value
    } else if (RegExp(r'[A-Z]').hasMatch(c)) {
      v = c.codeUnitAt(0) - 55; // A=10, B=11, ..., Z=35
    } else {
      v = 0; // '<' and any non-alphanum count as 0
    }
    sum += v * weights[i % 3]; // multiply by repeating weights 7, 3, 1
  }

  return (sum % 10).toString();
}


Map<String, dynamic> _visaValidationMap({
  required bool docOk,
  required bool documentCode,
  required bool birthOk,
  required bool expiryOk,
  required bool namesOk,
  required bool issuingOk,
  required bool nationalityOk,
  required int lineLen, // 44 or 36
}) {
  return {
    "docNumberValid": docOk,
    "birthDateValid": birthOk,
    "docCodeValid": documentCode,
    "expiryDateValid": expiryOk,
    "personalNumberValid": true, // MRV optional field has no check digit; treat as present/ok
    "finalCheckValid": true,    // visas don't have composite final
    "hasFinalCheck": false,      // <-- important for UI
    "nameValid": namesOk,
    "linesLengthValid": (lineLen == 36 || lineLen == 44),
    "countryValid": issuingOk,
    "nationalityValid": nationalityOk,
  };
}

Map<String, dynamic> _visaCheckDigitsMap({
  required bool docOk,
  required bool birthOk,
  required bool expiryOk,
}) {
  return {
    "document": docOk,   // unified key
    "passport": docOk,   // keep legacy key for compatibility
    "birth": birthOk,
    "expiry": expiryOk,
    "optional": true,    // MRV optional data has no own check digit
    // no "final" for visas; omit -> will deserialize as null
  };
}
