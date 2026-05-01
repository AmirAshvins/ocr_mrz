import 'dart:developer';

import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';
import 'package:ocr_mrz/doc_code_validator.dart';
import 'package:ocr_mrz/mrz_result_class_fix.dart';
import 'package:ocr_mrz/ocr_mrz_settings_class.dart';
import 'package:ocr_mrz/travel_doc_util.dart';

import 'my_name_handler.dart';
import 'orc_mrz_log_class.dart';

enum DocumentStandardType { td1, td2, td3 }

const _normMap = {
  '«': '<',
  '|': '<',
  '\\': '<',
  '/': '<',
  '“': '<',
  '”': '<',
  '’': '<',
  '‘': '<',
  ' ': '<',
  '—': '-', // rarely present; we strip to '-' then filtered out
  '–': '-',
};

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

String stripSexFromDateSex(String block) {
  if (block.length != 15) {
    throw ArgumentError('dateSex block must be exactly 15 characters');
  }
  return block.substring(0, 7) + block.substring(8); // skip char at index 7
}

String fixAlphaOnlyField(String value) {
  final map = {'0': 'O', '1': 'I', '5': 'S', '8': 'B', '6': 'G'};
  return value.toUpperCase().split('').map((c) => map[c] ?? c).join();
}

String fixExceptionalCountry(String value) {
  final map = {
    'D<<': 'DEU',
    'D': 'DEU',
    'D  ': 'DEU',
    'BAH': 'ZWE',
    'ZIM': 'ZWE',
    'UK': 'GBR',
    'UK<': 'GBR',
    'UK ': 'GBR',
    'SUN': 'RUS',
    'GRE': 'GRC',
    'CSK': 'CZE',
    'I': 'ITA',
    'I<<': 'ITA',
    'I  ': 'ITA',
    'F  ': 'FRA',
    'F<<': 'FRA',
    'F': 'FRA',
    'A  ': 'AUT',
    'A<<': 'AUT',
    'A': 'AUT',
    'CH ': 'CHE',
    'CH<': 'CHE',
    'CH': 'CHE',
  };
  if (map.keys.contains(value)) {
    return map[value]!;
  } else {
    return value;
  }

  // return value.toUpperCase().split('').map((c) => map[c] ?? c).join();
}

List<String> parseOldNumNat(String secondLineFixed) {
  final List<String> result = [];
  // 1) Extract MRZ doc number field and its check digit (positions 1–9 and 10)
  final mrzDocField = secondLineFixed.substring(0, 9); // [0..8]
  final mrzDocCheck = secondLineFixed.substring(9, 10); // [9]
  final baseDocNumber = mrzDocField.replaceAll('<', '');

  final docNumberValid = _computeMrzCheckDigit(mrzDocField) == mrzDocCheck;

  // 2) Nationality (positions 11–13)
  final nationalityField = secondLineFixed.substring(10, 13); // [10..12]
  final nationality = fixAlphaOnlyField(nationalityField);
  final nationalityValid = isValidMrzCountry(nationality);

  // 3) Try to extend doc number from the Optional Data / Personal Number
  //    field (positions 29–43 -> [28..42]). Position 44 ([43]) is its check digit.
  final optionalData = secondLineFixed.substring(28, 43);

  // Heuristic: if optional data starts with alphanumerics, treat the very first
  // run (until first '<') as a continuation, up to 3 chars.
  final contRaw = optionalData.split('<').first;
  final contClean = contRaw.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final continuation = contClean.isEmpty ? '' : contClean.substring(0, contClean.length.clamp(0, 3));

  // Build a "full" doc number (for UIs/DBs that want 9–12 chars).
  // The MRZ check digit STILL only validates the 9-char MRZ field.
  String fullDocNumber = (baseDocNumber + continuation);
  if (fullDocNumber.length > 12) {
    fullDocNumber = fullDocNumber.substring(0, 12);
  }
  // Ensure at least the base 9 remain
  if (fullDocNumber.length < baseDocNumber.length) {
    fullDocNumber = baseDocNumber;
  }

  if (docNumberValid && nationalityValid) {
    result.add(fullDocNumber);
    result.add(nationality);
  }

  return result;
}

final issueDateYYMMDD = RegExp(r'(?<!\d)(\d{2})(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])(?!\d)', caseSensitive: false);

class MyOcrHandler {
  static OcrMrzResult? handle(OcrData ocr, void Function(OcrMrzLog log)? mrzLogger) {
    OcrMrzValidation validation = OcrMrzValidation();
    DocumentStandardType? type;
    String? format;
    String? docNumber;
    String? firstName;
    String? lastName;
    DateTime? birthDate;
    DateTime? expiryDate;
    DateTime? issueDate;
    String? countryCode;
    String? nationality;
    String? issuing;
    String? docCode;
    String? sex;
    String? optional;
    MrzName? name;

    String finalCheckValue = "";

    List<String> rawLines = ocr.lines.map((a) => a.text).toList();
    List<String> rawMrzLines = [];
    List<String> otherLines = [];

    if (rawLines.any((a) => a.contains("<<"))) {
      String firstLine = rawLines.firstWhere((a) => a.contains("<<"));
      int firstLineIndex = rawLines.indexOf(firstLine);
      rawMrzLines.add(firstLine);
      if (firstLineIndex < rawLines.length - 1) {
        String secondLine = rawLines[firstLineIndex + 1];
        rawMrzLines.add(secondLine);
      }
      if (firstLineIndex < rawLines.length - 2) {
        String thirdLine = rawLines[firstLineIndex + 2];
        if (thirdLine.contains("<")) {
          rawMrzLines.add(thirdLine);
        }
      }
      List<String> fixedMrzLines;
      if (rawMrzLines.length < 3) {
        if (rawMrzLines.first.length > 40) {
          type = DocumentStandardType.td3;
          format = "td3";

          fixedMrzLines = rawMrzLines.map((a) => normalize(a, len: 44)).toList();
        } else {
          type = DocumentStandardType.td2;
          format = "td2";
          fixedMrzLines = rawMrzLines.map((a) => normalize(a, len: 36)).toList();
        }
      } else {
        format = "td1";
        type = DocumentStandardType.td1;
        fixedMrzLines = rawMrzLines.map((a) => normalize(a, len: 30)).toList();
      }
      log("\n${fixedMrzLines.join("\n")}");

      otherLines = [...rawLines].where((a) => !rawMrzLines.contains(a)).toList();
      if (fixedMrzLines.length < 2) return null;
      validation.linesLengthValid = true;

      final firstLineFixed = fixedMrzLines.first;
      final secondLineFixed = fixedMrzLines[1];
      docCode = firstLineFixed.substring(0, 2);
      countryCode = firstLineFixed.substring(2, 5);
      issuing = firstLineFixed.substring(2, 5);

      validation.docCodeValid = DocumentCodeHelper.isValid(docCode);
      validation.countryValid = isValidMrzCountry(countryCode);

      if (!validation.countryValid) {
        log("country $countryCode is not valid");
      }

      final mrzDatesSex = RegExp(r'(\d{6})(\d)([MFX<])(\d{6})(\d)', caseSensitive: false);
      final dateSexMatch = mrzDatesSex.firstMatch(secondLineFixed);
      if (dateSexMatch != null) {
        final birthDateStr = dateSexMatch.group(1);
        final birthCheck = dateSexMatch.group(2);
        final sexStr = dateSexMatch.group(3);
        final expiryDateStr = dateSexMatch.group(4);
        final expiryCheck = dateSexMatch.group(5);

        validation.birthDateValid = _computeMrzCheckDigit(birthDateStr!) == birthCheck;
        validation.expiryDateValid = _computeMrzCheckDigit(expiryDateStr!) == expiryCheck;
        birthDate = _parseMrzDate(birthDateStr);
        expiryDate = _parseMrzDate(expiryDateStr);
        sex = sexStr;
      }

      if (type == DocumentStandardType.td3) {
        final td3DocNumber = RegExp(r'^([A-Z0-9<]{9})(\d)', caseSensitive: false);
        final td3DocNumberMatch = td3DocNumber.firstMatch(secondLineFixed);
        if (td3DocNumberMatch != null) {
          final docNumberStr = td3DocNumberMatch.group(1);
          final docNumberCheckStr = td3DocNumberMatch.group(2);
          docNumber = docNumberStr;
          validation.docNumberValid = _computeMrzCheckDigit(docNumberStr ?? '') == docNumberCheckStr;

          finalCheckValue += docNumberStr ?? '';
          finalCheckValue += docNumberCheckStr ?? '';
        }

        final td3Nationality = RegExp(r'^[A-Z0-9<]{10}([A-Z0-9<]{3})', caseSensitive: false);
        final td3NationalityMatch = td3Nationality.firstMatch(secondLineFixed);
        if (td3NationalityMatch != null) {
          final nationalityStr = fixAlphaOnlyField(td3NationalityMatch.group(1)!);
          nationality = nationalityStr;
          validation.nationalityValid = isValidMrzCountry(nationalityStr);
        }

        if (!validation.docNumberValid) {
          final oldFixes = parseOldNumNat(secondLineFixed);
          if (oldFixes.length == 2) {
            docNumber = oldFixes[0];
            nationality = oldFixes[1];
            validation.docNumberValid = true;
            validation.nationalityValid = true;
          }
        }

        if (dateSexMatch != null) {
          finalCheckValue += stripSexFromDateSex(dateSexMatch.group(0)!);
        }

        final td3OptionalFinal = RegExp(r'^.{28}([A-Z0-9<]{15})(\d)$', caseSensitive: false);
        final td3OptionalFinalMatch = td3OptionalFinal.firstMatch(secondLineFixed);

        if (td3OptionalFinalMatch != null) {
          final optionalStr = td3OptionalFinalMatch.group(1);
          final finalCheckStr = td3OptionalFinalMatch.group(2);

          optional = optionalStr;
          finalCheckValue += (optionalStr ?? '');

          validation.personalNumberValid = true;
          validation.hasFinalCheck = true;
          validation.finalCheckValid = _computeMrzCheckDigit(finalCheckValue) == finalCheckStr;

          final issueDateMatch = issueDateYYMMDD.firstMatch(optionalStr ?? '');
          if (issueDateMatch != null) {
            final issueDateStr = issueDateMatch.group(0); // "220620"
            issueDate = _parseMrzDate(issueDateStr!);
          }
        }

        name = parseNamesTd3OrTd2(firstLineFixed);
      } else if (type == DocumentStandardType.td2) {
        final td2DocNumber = RegExp(r'^([A-Z0-9<]{9})(\d)', caseSensitive: false);
        final td2DocNumberMatch = td2DocNumber.firstMatch(secondLineFixed);
        if (td2DocNumberMatch != null) {
          final docNumberStr = td2DocNumberMatch.group(1);
          final docNumberCheckStr = td2DocNumberMatch.group(2);
          docNumber = docNumberStr;
          validation.docNumberValid = _computeMrzCheckDigit(docNumberStr ?? '') == docNumberCheckStr;

          finalCheckValue += (docNumberStr ?? '');
          finalCheckValue += (docNumberCheckStr ?? '');
        }

        final td2Nationality = RegExp(r'^[A-Z0-9<]{10}([A-Z<]{3})', caseSensitive: false);
        final td2NationalityMatch = td2Nationality.firstMatch(secondLineFixed);
        if (td2NationalityMatch != null) {
          final nationalityStr = fixAlphaOnlyField(td2NationalityMatch.group(1)!);
          nationality = nationalityStr;
          validation.nationalityValid = isValidMrzCountry(nationalityStr);
          finalCheckValue += nationalityStr;
        }

        if (dateSexMatch != null) {
          finalCheckValue += dateSexMatch.group(0)!;
        }

        final td2OptionalFinal = RegExp(r'^.{28}([A-Z0-9<]{7})(\d)$', caseSensitive: false);
        final td2OptionalFinalMatch = td2OptionalFinal.firstMatch(secondLineFixed);

        if (td2OptionalFinalMatch != null) {
          final optionalStr = td2OptionalFinalMatch.group(1);
          final finalCheckStr = td2OptionalFinalMatch.group(2);

          if (docCode.startsWith("V")) {
            validation.hasFinalCheck = true;
            validation.personalNumberValid = true;
            validation.finalCheckValid = true;
          } else {
            optional = optionalStr;
            finalCheckValue += (optionalStr ?? '');
            validation.personalNumberValid = true;
            validation.hasFinalCheck = true;
            validation.finalCheckValid = _computeMrzCheckDigit(finalCheckValue) == finalCheckStr;

            final issueDateMatch = issueDateYYMMDD.firstMatch(optionalStr ?? '');
            if (issueDateMatch != null) {
              final issueDateStr = issueDateMatch.group(0);
              issueDate = _parseMrzDate(issueDateStr!);
            }
          }
        }

        name = parseNamesTd3OrTd2(firstLineFixed);
      } else if (type == DocumentStandardType.td1) {
        docNumber = firstLineFixed.substring(5, 14);
        final docNumberCheck = firstLineFixed[14];
        validation.docNumberValid = _computeMrzCheckDigit(docNumber) == docNumberCheck;

        finalCheckValue += firstLineFixed.substring(5, 30);

        if (dateSexMatch != null) {
          finalCheckValue += stripSexFromDateSex(dateSexMatch.group(0)!);
        }

        final td1Nationality = RegExp(r'^.{15}([A-Z<]{3})', caseSensitive: false);
        final td1NationalityMatch = td1Nationality.firstMatch(secondLineFixed);
        if (td1NationalityMatch != null) {
          final nationalityStr = fixAlphaOnlyField(td1NationalityMatch.group(1)!);
          nationality = nationalityStr;
          validation.nationalityValid = isValidMrzCountry(nationalityStr);
        }

        final td1OptionalFinal = RegExp(r'^.{18}([A-Z0-9<]{11})(\d)$', caseSensitive: false);
        final td1OptionalFinalMatch = td1OptionalFinal.firstMatch(secondLineFixed);

        if (td1OptionalFinalMatch != null) {
          final optionalStr = td1OptionalFinalMatch.group(1);
          final finalCheckStr = td1OptionalFinalMatch.group(2);
          optional = optionalStr;
          final issueDateMatch = issueDateYYMMDD.firstMatch(optionalStr ?? '');
          if (issueDateMatch != null) {
            final issueDateStr = issueDateMatch.group(0);
            issueDate = _parseMrzDate(issueDateStr!);
          }
          finalCheckValue += (optionalStr ?? '');
          validation.personalNumberValid = true;
          validation.hasFinalCheck = true;
          validation.finalCheckValid = _computeMrzCheckDigit(finalCheckValue) == finalCheckStr;
        }
        String nameLine = fixedMrzLines.last;
        name = parseNamesTd1(nameLine);
      }

      if (name != null) {
        firstName = name.givenNames.join(" ");
        lastName = name.surname;
        validation.nameValid = name.validateNames(otherLines, OcrMrzSetting(nameValidationMode: NameValidationMode.exact), []).$1;
      }

      log(validation.toString());
      log("-" * 100);

      OcrMrzResult result = OcrMrzResult(
        line1: firstLineFixed,
        line2: secondLineFixed,
        format: format,
        documentCode: docCode,
        documentType: type.name.toUpperCase(),
        mrzFormat: format,
        issueDate: issueDate,
        countryCode: fixExceptionalCountry(countryCode),
        issuingState: fixExceptionalCountry(issuing),
        lastName: lastName ?? '',
        firstName: firstName ?? '',
        documentNumber: docNumber?.replaceAll("<", "") ?? '',
        nationality: fixExceptionalCountry(nationality ?? ''),
        birthDate: birthDate,
        expiryDate: expiryDate,
        sex: sex ?? '',
        personalNumber: optional ?? '',
        optionalData: optional ?? '',
        valid: validation,
        checkDigits: CheckDigits(document: true, birth: true, expiry: true, optional: true),
        ocrData: ocr,
      );
      mrzLogger?.call(OcrMrzLog(rawText: ocr.text, rawMrzLines: rawMrzLines, fixedMrzLines: fixedMrzLines, validation: validation, extractedData: result.toJson()));
      return result;
    } else {
      // log("No Ocr");
    }
    return null;
  }

  static String normalize(String line, {int len = 44}) {
    line = line.replaceAll(" ", '');
    final b = StringBuffer();
    for (final rune in line.toUpperCase().runes) {
      var ch = String.fromCharCode(rune);
      ch = _normMap[ch] ?? ch;
      final cu = ch.codeUnitAt(0);
      final isAZ = cu >= 65 && cu <= 90;
      final is09 = cu >= 48 && cu <= 57;
      if (isAZ || is09 || cu == 60) {
        b.writeCharCode(cu);
        if (b.length == len) break;
      }
    }
    while (b.length < len) b.write('<');
    return b.toString();
  }

  static OcrMrzResult? debug(String s) {
    OcrMrzResult? res = handle(OcrData(text: s, lines: s.split("\n").map((oc) => OcrLine(text: oc, cornerPoints: [])).toList()), null);
    return res;
  }
}
