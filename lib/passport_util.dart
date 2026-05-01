import 'dart:developer';

import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';
import 'package:ocr_mrz/doc_code_validator.dart';
import 'package:ocr_mrz/mrz_result_class_fix.dart';
import 'package:ocr_mrz/name_validation_data_class.dart';
import 'package:ocr_mrz/orc_mrz_log_class.dart';

import 'ocr_mrz_settings_class.dart';
import 'travel_doc_util.dart';

String _normalizeLine(String line) {
  final map = {
    '«': '<',
    '|': '<',
    '\\': '<',
    '/': '<',
    '“': '<',
    '”': '<',
    '’': '<',
    '‘': '<',
    ' ': '<',
    // 'O': '0',
    // 'Q': '0',
  };

  String normalized = line.toUpperCase().split('').map((c) => map[c] ?? c).join();

  // Step 1: Replace suspicious sequences of K with '<'
  normalized = normalized.replaceAll(RegExp(r'K{2,}'), '<'); // Replace KK, KKK, etc.
  normalized = normalized.replaceAll(RegExp(r'X{2,}'), '<'); // Replace XX, XXX, etc.

  // Step 2: Replace K that appears between < symbols (e.g., <K< → <<<)
  normalized = normalized.replaceAllMapped(RegExp(r'<K<'), (m) => '<<<');
  normalized = normalized.replaceAllMapped(RegExp(r'<X<'), (m) => '<<<');

  // Step 3: Leave single 'K's untouched elsewhere — assume they're valid
  // You could optionally handle edge cases here

  // Step 4: Remove invalid characters and enforce MRZ format
  return normalized.split('').where((c) => RegExp(r'[A-Z0-9<]').hasMatch(c)).join().padRight(44, '<').substring(0, 44);
}

Map<String, dynamic>? tryParseMrzFromOcrLines(OcrData ocrData, OcrMrzSetting? setting, List<NameValidationData>? nameValidations, void Function(OcrMrzLog log)? mrzLogger) {
  List<String> ocrLines = ocrData.lines.map((a) => a.text).toList();
  final mrzLines = ocrLines.where((a) => a.length > 35 && a.contains("<")).map(_normalizeLine).where((line) => line.length == 44 && line.contains(RegExp(r'<{1,}'))).toList();
  final rawMrzLines = [...ocrLines.where((a) => a.length > 35 && a.contains("<"))];
  if (mrzLines.length < 2) {
    mrzLogger?.call(OcrMrzLog(rawText: ocrData.text, rawMrzLines: rawMrzLines, fixedMrzLines: mrzLines, validation: OcrMrzValidation(), extractedData: {}));
    return null;
  }

  var line1 = mrzLines[mrzLines.length - 2];
  var line2 = mrzLines[mrzLines.length - 1];

  final oldLine1 = line1;
  final oldLine2 = line2;
  List<String> otherLines = ocrLines.where((a) => !mrzLines.contains(a) && !a.contains("<")).toList();

  line1 = normalizeMrzLine1(line1); // ✅ repaired
  line2 = repairMrzLine2Strict(line2); // ✅ repaired
  line2 = repairSpecificFields(line2);

  try {
    final documentType = line1.substring(0, 1);
    final documentCode = line1.substring(0, 2);
    final countryCode = fixAlphaOnlyField(line1.substring(2, 5));
    final nameParts = line1.substring(5).split('<<');
    var lastName = nameParts[0].replaceAll('<', ' ').trim();
    var firstName = nameParts.length > 1 ? nameParts[1].replaceAll('<', ' ').trim() : '';
    firstName = _cleanMrzName(firstName);
    lastName = _cleanMrzName(lastName);

    final passportNumber = line2.substring(0, 9).replaceAll('<', '');
    final passportCheck = line2.substring(9, 10);
    final nationality = fixAlphaOnlyField(line2.substring(10, 13));
    final birthDate = line2.substring(13, 19);
    final birthCheck = line2.substring(19, 20);
    final sex = line2.substring(20, 21);
    final expiryDate = line2.substring(21, 27);
    final expiryCheck = line2.substring(27, 28);
    final personalNumber = line2.substring(28, 42);
    final personalCheck = line2.substring(42, 43);
    final finalCheck = line2.substring(43, 44);

    final validPassport = _computeMrzCheckDigit(line2.substring(0, 9)) == passportCheck;
    final validBirth = _computeMrzCheckDigit(birthDate) == birthCheck;
    final validExpiry = _computeMrzCheckDigit(expiryDate) == expiryCheck;
    final validOptional = _computeMrzCheckDigit(personalNumber) == personalCheck;

    final composite = line2.substring(0, 10) + birthDate + birthCheck + expiryDate + expiryCheck + personalNumber + personalCheck;
    final validFinal = _computeMrzCheckDigit(composite) == finalCheck;

    final validateSettings = setting ?? OcrMrzSetting();
    final validation = validateMrzLine(
      line1: line1,
      line2: line2,
      otherLines: otherLines,
      firstName: firstName,
      lastName: lastName,
      setting: validateSettings,
      country: countryCode,
      nationality: nationality,
      personalNumber: personalNumber,
      nameValidations: nameValidations,
      code: documentCode,
    );

    final resultMap = {
      'line1': line1,
      'line2': line2,
      'documentCode': documentCode,
      'documentType': documentType,
      'countryCode': countryCode,
      'lastName': lastName,
      'firstName': firstName,
      'passportNumber': passportNumber,
      'nationality': nationality,
      'birthDate': _parseMrzDate(birthDate)?.toIso8601String(),
      'expiryDate': _parseMrzDate(expiryDate)?.toIso8601String(),
      'sex': sex,
      'personalNumber': personalNumber,
      'valid': validation.toJson(),
      'checkDigits': {'passport': validPassport, 'birth': validBirth, 'expiry': validExpiry, 'optional': validOptional, 'final': validFinal},
      "ocrData": ocrData.toJson(),
      'format': MrzFormat.TD3.toString().split('.').last,
    };

    mrzLogger?.call(OcrMrzLog(rawText: ocrData.text, rawMrzLines: rawMrzLines, fixedMrzLines: [line1, line2], validation: validation, extractedData: resultMap));

    if (firstName.trim().isEmpty && lastName.trim().isEmpty) {
      return null;
    }

    // log("----");

    if (validation.linesLengthValid) {
      // log("----1");
      // log("\n$oldLine1\n$oldLine2\n${"-"*50}\n$line1\n$line2\n$validation\n${passportNumber} - ${birthDate} - ${expiryDate} - ${personalNumber}  - ${countryCode} - ${nationality} - ${firstName} ${lastName}");
      // log(validation.toString());
    }

    if (validateSettings.validateNames && !validation.nameValid) {
      // log("$line1\n$line2");
      // log("----2");
      return null;
    }
    if (validateSettings.validateBirthDateValid && !validation.birthDateValid) {
      // log("$line1\n$line2");
      // log("----3");
      return null;
    }
    if (validateSettings.validateDocNumberValid && !validation.docNumberValid) {
      // log("$line1\n$line2");
      // log("----4");
      return null;
    }
    if (validateSettings.validateExpiryDateValid && !validation.expiryDateValid) {
      // log("$line1\n$line2");
      // log("----5");
      return null;
    }
    if (validateSettings.validateFinalCheckValid && !validation.finalCheckValid) {
      // log("----6");
      // log("$line1\n$line2");
      return null;
    }
    if (validateSettings.validateLinesLength && !validation.linesLengthValid) {
      // log("$line1\n$line2");
      // log("----7");
      return null;
    }
    if (validateSettings.validatePersonalNumberValid && !validation.personalNumberValid) {
      // log("$line1\n$line2");
      // log("----7");
      // log("Personal number is ${personalNumber}");
      return null;
    }
    if (validateSettings.validateCountry && !validation.countryValid) {
      // log("$line1\n$line2");
      // log("----8");
      return null;
    }
    if (validateSettings.validateNationality && !validation.nationalityValid) {
      // log("$line1\n$line2");
      // log("----1");
      return null;
    }

    return resultMap;
  } catch (e) {
    log("${e}");
    return null;
  }
}

String _computeMrzCheckDigit(String input) {
  final weights = [7, 3, 1];
  int sum = 0;

  for (int i = 0; i < input.length; i++) {
    final c = input[i];
    int v;
    if (RegExp(r'[0-9]').hasMatch(c)) {
      v = int.parse(c);
    } else if (RegExp(r'[A-Z]').hasMatch(c)) {
      v = c.codeUnitAt(0) - 55;
    } else {
      v = 0;
    }
    sum += v * weights[i % 3];
  }

  return (sum % 10).toString();
}

String normalizeMrzLine1(String line) {
  return line.replaceAll('0', 'O').replaceAll('1', 'I').replaceAll('5', 'S'); // Optional: only if you encounter '5' errors in names
}

String repairMrzLine2Strict(String rawLine) {
  final Map<String, String> replacements = {
    '«': '<', '|': '<', '\\': '<', '/': '<', '“': '<', '”': '<',
    '’': '<', '‘': '<', ' ': '<',
    'O': '0',
    // 'Q': '0', 'I': '1', 'L': '1', 'Z': '2', 'S': '5', 'B': '8', 'G': '6'
    // DO NOT add K/X as global replacement!
  };

  String cleaned = rawLine.toUpperCase().split('').map((c) => replacements[c] ?? c).where((c) => RegExp(r'[A-Z0-9<]').hasMatch(c)).join();
  if (cleaned.length < 44) cleaned = cleaned.padRight(44, '<');
  if (cleaned.length > 44) cleaned = cleaned.substring(0, 44);

  List<String> generateCandidates(String line) {
    final List<String> results = [line];

    for (int i = 0; i < line.length; i++) {
      if (line[i] == '<') {
        results.add(line.substring(0, i) + line.substring(i + 1));
      }
    }

    for (int i = 0; i < line.length; i++) {
      if (line[i] != '<') continue;
      for (int j = i + 1; j < line.length; j++) {
        if (line[j] != '<') continue;
        final removed = line.substring(0, i) + line.substring(i + 1, j) + line.substring(j + 1);
        results.add(removed);
      }
    }

    return results;
  }

  for (final candidate in generateCandidates(cleaned)) {
    String line = candidate;
    if (line.length < 44) line = line.padRight(44, '<');
    if (line.length > 44) line = line.substring(0, 44);

    final birth = line.substring(13, 19);
    final birthCheck = line[19];
    final expiry = line.substring(21, 27);
    final expiryCheck = line[27];

    final personalNum = line.substring(28, 42);
    final personalCheck = line[42];
    final finalCheck = line[43];

    final isBirthValid = RegExp(r'^\d{6}$').hasMatch(birth) && _computeMrzCheckDigit(birth) == birthCheck;
    final isExpiryValid = RegExp(r'^\d{6}$').hasMatch(expiry) && _computeMrzCheckDigit(expiry) == expiryCheck;

    // Optional validations:
    final isPersonalValid = personalNum.replaceAll('<', '').isEmpty ? (personalCheck == '0' || personalCheck == '<') : (_computeMrzCheckDigit(personalNum) == personalCheck);

    final finalCheckInput = line.substring(0, 10) + line.substring(13, 20) + line.substring(21, 43);
    final isFinalValid = _computeMrzCheckDigit(finalCheckInput) == finalCheck;

    final validSex = line[20] == 'M' || line[20] == 'F' || line[20] == '<';

    if (isBirthValid && isExpiryValid && isPersonalValid && isFinalValid && validSex) {
      return line;
    }
  }

  // fallback
  return cleaned;
}

String repairSpecificFields(String line) {
  if (line.length != 44) return line; // safety check

  // Fix nationality field (index 10–13)
  final nat =
      line.substring(10, 13).split('').map((c) {
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

  // Fix personal number field (index 28–42)
  final personalRaw = line.substring(28, 42);
  final digits = personalRaw.replaceAll(RegExp(r'(?<=\d)<(?=\d)'), ''); // remove `<` only between digits
  final padded = digits.padRight(14, '<').substring(0, 14);

  // Build and return new line
  final result = line.substring(0, 10) + nat + line.substring(13, 28) + padded + line.substring(42);
  // log(" repairSpecificFields\n$line\n$result");
  return result;
}

OcrMrzValidation validateMrzLine({
  required String line1,
  required String line2,
  required String code,
  required OcrMrzSetting setting,
  required List<String> otherLines,
  required String firstName,
  required String lastName,
  required String country,
  required String nationality,
  required String personalNumber,
  required List<NameValidationData>? nameValidations,
}) {
  OcrMrzValidation validation = OcrMrzValidation();
  try {
    validation.linesLengthValid = (line2.length == 44 && line1.length == 44);

    String docCode = code;
    bool isDocCodeValid = DocumentCodeHelper.isValid(docCode);
    validation.docCodeValid = isDocCodeValid;

    String docNumber = line2.substring(0, 9);
    String docCheck = line2[9];
    bool isDocNumberValid = _computeMrzCheckDigit(docNumber) == docCheck;
    validation.docNumberValid = isDocNumberValid;

    String birthDate = line2.substring(13, 19);
    String birthCheck = line2[19];
    bool isBirthDateValid = (RegExp(r'^\d{6}$').hasMatch(birthDate) && _computeMrzCheckDigit(birthDate) == birthCheck);
    validation.birthDateValid = isBirthDateValid;

    String expiryDate = line2.substring(21, 27);
    String expiryCheck = line2[27];
    bool isExpiryDateValid = (RegExp(r'^\d{6}$').hasMatch(expiryDate) && _computeMrzCheckDigit(expiryDate) == expiryCheck);
    validation.expiryDateValid = isExpiryDateValid;

    // String personalNumber = personalNumber;
    String personalCheck = line2[42];
    final isPersonalValid = personalNumber.replaceAll('<', '').isEmpty ? (personalCheck == '0' || personalCheck == '<') : (_computeMrzCheckDigit(personalNumber) == personalCheck);
    validation.personalNumberValid = isPersonalValid;

    String finalCheck = line2[43];
    bool isFinalCheckValid = _computeMrzCheckDigit(docNumber + docCheck + birthDate + birthCheck + expiryDate + expiryCheck + personalNumber + personalCheck) == finalCheck;
    validation.finalCheckValid = isFinalCheckValid;

    bool validNames = validateNames(firstName, lastName, otherLines);
    bool isNamesValid = validNames;
    validation.nameValid = isNamesValid;
    if (!isNamesValid && nameValidations != null) {
      if (nameValidations.any((a) => a.firstName.toLowerCase() == firstName.toLowerCase() && a.lastName.toLowerCase() == lastName.toLowerCase())) {
        isNamesValid = true;
        validation.nameValid = true;
      }
    }

    bool validCountry = isValidMrzCountry(country);
    bool isValidCountry = validCountry;
    validation.countryValid = isValidCountry;

    bool validNationality = isValidMrzCountry(nationality);
    bool isValidNationality = validNationality;
    validation.nationalityValid = isValidNationality;

    return validation;
  } catch (e) {
    return validation;
  }
}

String _cleanMrzName(String input) {
  return input
      .replaceAll('0', 'O')
      .replaceAll('1', 'I')
      .replaceAll('5', 'S')
      .replaceAll(RegExp(r'[2-9]'), '') // remove other digits
      .replaceAll('<', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
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
    return DateTime(fullYear, month, day);
  } catch (_) {
    return null;
  }
}

bool validateNames(String firstName, String lastName, Iterable<String> lines) {
  List<String> words = [];
  for (var l in lines) {
    words.addAll(extractWords(l).map((a) => a.toLowerCase()));
  }
  final isFirstNameValid = firstName.trim().isEmpty || firstName.toLowerCase().split(" ").every((a) => words.contains(a.toLowerCase()));
  final isLastNameValid = lastName.trim().isEmpty || lastName.toLowerCase().split(" ").every((a) => words.contains(a.toLowerCase()));
  final res = isLastNameValid && isFirstNameValid;

  return res;
}

List<String> extractWords(String text) {
  final wordRegExp = RegExp(r'\b\w+\b');
  return wordRegExp.allMatches(text).map((match) => match.group(0)!).toList();
}
