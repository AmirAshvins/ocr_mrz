import 'dart:developer';

import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';
import 'package:ocr_mrz/doc_code_validator.dart';
import 'package:ocr_mrz/mrz_result_class_fix.dart';
import 'package:ocr_mrz/travel_doc_util.dart';

import 'my_name_handler.dart';
import 'ocr_mrz_settings_class.dart';
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

  // ---- Assign to your variables / validation state ----
  final docNumber = fullDocNumber; // what you expose/use
  final docNumberMrzField = baseDocNumber; // if you also want the 9-char as-is

  // Example of how you were accumulating for the final composite check:
  // (Keep using the MRZ field + its check digit for the composite per ICAO)
  var finalCheckValue = '';
  finalCheckValue += mrzDocField; // NOT fullDocNumber
  finalCheckValue += mrzDocCheck;

  if (docNumberValid && nationalityValid) {
    result.add(fullDocNumber);
    result.add(nationality);
  }

  // ... continue with birth, expiry, personal number, etc.

  // Your existing flags:
  // validation.docNumberValid = docNumberValid;
  // validation.nationalityValid = nationalityValid;
  return result;
}

class MyOcrHandlerNew {
  static OcrMrzResult? handle(OcrData ocr, void Function(OcrMrzLog log)? mrzLogger) {
    // secondLineFixed must be the full TD3 line 2 (length 44), already normalized (< padded).

    final _dateSexRe = RegExp(r'(\d{6})(\d)([MFX])(\d{6})(\d)', caseSensitive: false);

    final _td23Lead = RegExp(r'^[A-Z0-9<]{9}\d[A-Z<]{3}$'); // used on a 13-char slice from start

    String _normLine(String s) => s.toUpperCase().replaceAll(' ', '<').replaceAll(RegExp(r'[^A-Z0-9<\r\n]'), '<').trim();

    String _normalizeNat(String s) => s
        .toUpperCase()
        .replaceAll('1', 'I') // common OCR confusables
        .replaceAll('0', 'O');

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
    List<String> fixedMrzLines = [];
    String firstLineFixed = "";
    String secondLineFixed = "";
    String? thirdLineFixed;

    final lines = _normLine(ocr.text).split(RegExp(r'[\r\n]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (lines.isNotEmpty) {
      // 1) Find the line that contains the date+sex block (this is line2)
      int idx2 = -1;
      RegExpMatch? m;
      for (var i = 0; i < lines.length; i++) {
        final mm = _dateSexRe.firstMatch(lines[i]);
        if (mm != null) {
          idx2 = i;
          m = mm;
          break;
        }
      }
      if (idx2 != -1 && m != null) {
        // mrzLogger?.call(OcrMrzLog(rawText: ocr.text, rawMrzLines: rawMrzLines, fixedMrzLines: [], validation: validation, extractedData: {}));

        final line2 = lines[idx2];

        // 2) Decide TD1 vs TD2/TD3 by looking at start-of-line signature
        // If the first 13 chars look like doc(9)+chk(1)+nat(3) → TD2/TD3.
        final head13 = line2.length >= 13 ? line2.substring(0, 13) : line2;
        final looksTd23 = head13.length == 13 && _td23Lead.hasMatch(head13);

        // 4) Collect line1 (previous non-empty) and line3 (next non-empty) if present
        String line1 = '';
        String? line3;
        // previous non-empty line
        for (int i = idx2 - 1; i >= 0; i--) {
          if (lines[i].isNotEmpty) {
            line1 = lines[i];
            break;
          }
        }
        // next non-empty line
        for (int i = idx2 + 1; i < lines.length; i++) {
          if (lines[i].isNotEmpty) {
            line3 = lines[i];
            break;
          }
        }

        if (line3 == null) {
        } else {
          rawMrzLines = [line1, line2, line3];
        }

        // If we didn’t find line1 (sometimes input has only one line), keep empty.
        // For TD1 we expect a third line; for TD2/TD3 names are usually on line1.

        // log("\n${rawMrzLines.join("\n")}");

        // Also use length as a hint to pick TD2 vs TD3 later
        if (looksTd23) {
          // Differentiate TD2 vs TD3 by typical lengths (36 vs 44)
          if (line2.length >= 40) {
            type = DocumentStandardType.td3;
            format = "td3";
            rawMrzLines = [line1, line2];
            fixedMrzLines = rawMrzLines.map((a) => normalize(a, len: 44)).toList();
          } else if (line2.length >= 36) {
            type = DocumentStandardType.td2;
            format = 'td2';

            rawMrzLines = [line1, line2];
            fixedMrzLines = rawMrzLines.map((a) => normalize(a, len: 36)).toList();
          } else {
            format = "td2";

            rawMrzLines = [line1, line2];
            fixedMrzLines = rawMrzLines.map((a) => normalize(a, len: 30)).toList();
            // fallback: date block position near 13 strongly suggests TD2/TD3
            type = DocumentStandardType.td2;
          }
        } else {
          format = "td1";

          rawMrzLines = [line1, line2, line3 ?? ''];
          fixedMrzLines = rawMrzLines.map((a) => normalize(a, len: 30)).toList();
          type = DocumentStandardType.td1;
        }

        int newIdx2 = -1;
        RegExpMatch? newM;
        for (var i = 0; i < fixedMrzLines.length; i++) {
          final mm = _dateSexRe.firstMatch(fixedMrzLines[i]);
          if (mm != null) {
            newIdx2 = i;
            newM = mm;
            break;
          }
        }
        if (newIdx2 != -1 && newM != null) {
          // mrzLogger?.call(OcrMrzLog(rawText: ocr.text, rawMrzLines: rawMrzLines, fixedMrzLines: fixedMrzLines, validation: validation, extractedData: {}));

          final dsStart = newM.start; // start index of YYMMDD+chk+sex+YYMMDD+chk in line2
          final birthStr = newM.group(1)!;
          final birthChkStr = newM.group(2)!;
          final sexStr = newM.group(3)!;
          final expiryStr = newM.group(4)!;
          final expiryChkStr = newM.group(5)!;

          // 3) Extract nationality relative to the date+sex block
          String nationalityRaw;
          if (type == DocumentStandardType.td1) {
            // TD1: nationality is AFTER the 15-char date+sex block (pos 15..17)
            final natStart = dsStart + 15;
            final natEnd = natStart + 3;
            nationalityRaw = (natEnd <= line2.length) ? line2.substring(natStart, natEnd) : '';
          } else {
            // TD2/TD3: nationality is the 3 chars BEFORE the date+sex block
            final natStart = dsStart - 3;
            final natEnd = dsStart;
            nationalityRaw = (natStart >= 0) ? line2.substring(natStart, natEnd) : '';
          }
          nationality = _normalizeNat(nationalityRaw);

          if (isValidMrzCountry(nationality)) {
            // mrzLogger?.call(OcrMrzLog(rawText: ocr.text, rawMrzLines: rawMrzLines, fixedMrzLines: [], validation: validation, extractedData: {}));

            log("nationality is valid");
            otherLines = [...rawLines].where((a) => !rawMrzLines.contains(a)).toList();
            if (fixedMrzLines.length >= 2) {
              validation.linesLengthValid = true;

              firstLineFixed = fixedMrzLines.first;
              docCode = firstLineFixed.substring(0, 2);
              countryCode = firstLineFixed.substring(2, 5);
              issuing = firstLineFixed.substring(2, 5);

              validation.docCodeValid = DocumentCodeHelper.isValid(docCode);
              validation.countryValid = isValidMrzCountry(countryCode);

              if (!validation.countryValid) {
                log("country ${countryCode} is no valid");
              }

              secondLineFixed = fixedMrzLines[1];
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
                  // log("nationalityStr ${nationalityStr}");
                  nationality = nationalityStr;
                  validation.nationalityValid = isValidMrzCountry(nationalityStr ?? '');
                } else {
                  // log("td3NationalityMatch no match");
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
                }

                name = parseNamesTd3OrTd2(firstLineFixed);
              } else if (type == DocumentStandardType.td2) {
                // Doc number + check (pos 0..8, 9)
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

                // Nationality (pos 10..12)
                final td2Nationality = RegExp(r'^[A-Z0-9<]{10}([A-Z<]{3})', caseSensitive: false);
                final td2NationalityMatch = td2Nationality.firstMatch(secondLineFixed);
                if (td2NationalityMatch != null) {
                  final nationalityStr = fixAlphaOnlyField(td2NationalityMatch.group(1)!);
                  nationality = nationalityStr;
                  validation.nationalityValid = isValidMrzCountry(nationalityStr ?? '');
                  finalCheckValue += nationalityStr!;
                }

                // Dates + sex (pos 13..27)
                if (dateSexMatch != null) {
                  finalCheckValue += dateSexMatch.group(0)!;
                }

                // Optional (7) + final check (1) (pos 28..34, 35)
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
                    validation.personalNumberValid = true; // treat optional as personal no.
                    validation.hasFinalCheck = true;
                    validation.finalCheckValid = _computeMrzCheckDigit(finalCheckValue) == finalCheckStr;
                  }
                }

                name = parseNamesTd3OrTd2(firstLineFixed);
              } else if (type == DocumentStandardType.td1) {
                docNumber = firstLineFixed.substring(5, 14);
                final docNumberCheck = firstLineFixed[14];
                validation.docNumberValid = _computeMrzCheckDigit(docNumber) == docNumberCheck;

                finalCheckValue += firstLineFixed.substring(5, 30);

                // Dates + sex first (pos 0..14)
                if (dateSexMatch != null) {
                  finalCheckValue += stripSexFromDateSex(dateSexMatch.group(0)!);
                }

                // Nationality (pos 15..17)
                final td1Nationality = RegExp(r'^.{15}([A-Z<]{3})', caseSensitive: false);
                final td1NationalityMatch = td1Nationality.firstMatch(secondLineFixed);
                if (td1NationalityMatch != null) {
                  final nationalityStr = fixAlphaOnlyField(td1NationalityMatch.group(1)!);
                  nationality = nationalityStr;
                  validation.nationalityValid = isValidMrzCountry(nationalityStr ?? '');
                }

                // Optional (11) + final check (1) (pos 18..28, 29)
                final td1OptionalFinal = RegExp(r'^.{18}([A-Z0-9<]{11})(\d)$', caseSensitive: false);
                final td1OptionalFinalMatch = td1OptionalFinal.firstMatch(secondLineFixed);

                if (td1OptionalFinalMatch != null) {
                  final optionalStr = td1OptionalFinalMatch.group(1);
                  final finalCheckStr = td1OptionalFinalMatch.group(2);

                  optional = optionalStr;

                  final natMatch = RegExp(r'^.{15}([A-Z<]{3})', caseSensitive: false).firstMatch(secondLineFixed);
                  final nationalityForFinal = natMatch?.group(1) ?? '';

                  finalCheckValue += (optionalStr ?? ''); // positions 18..28
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
                var (a, _, __) = name.validateNames(otherLines, OcrMrzSetting(nameValidationMode: NameValidationMode.exact), []);
                validation.nameValid = a;
              }

              log(validation.toString());
              log("-" * 100);
            }
          }
        }
        // return null; // no MRZ date+sex found
      }
    }

    OcrMrzResult result = OcrMrzResult(
      line1: firstLineFixed,
      line2: secondLineFixed,
      format: format ?? 'unknown',
      documentCode: docCode ?? '',
      documentType: type?.name.toUpperCase() ?? '',
      mrzFormat: format,
      countryCode: fixExceptionalCountry(countryCode ?? ''),
      issuingState: fixExceptionalCountry(issuing ?? ''),

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
    if (rawMrzLines.isNotEmpty) {
      log("\n${rawMrzLines.join("\n")}");
      mrzLogger?.call(OcrMrzLog(rawText: ocr.text, rawMrzLines: rawMrzLines, fixedMrzLines: fixedMrzLines, validation: validation, extractedData: result.toJson()));
    } else {}
    return result;

    // log("\n${fixedMrzLines.join("\n")}");
    // return null;
    // /////////////////////////////////////////////////////////////////////////////
    // if (rawLines.any((a) => a.contains("<<"))) {
    //   // log("Has Ocr");
    //   String firstLine = rawLines.firstWhere((a) => a.contains("<<"));
    //   int firstLineIndex = rawLines.indexOf(firstLine);
    //   rawMrzLines.add(firstLine);
    //   if (firstLineIndex < rawLines.length - 1) {
    //     String secondLine = rawLines[firstLineIndex + 1];
    //     rawMrzLines.add(secondLine);
    //   }
    //   if (firstLineIndex < rawLines.length - 2) {
    //     String thirdLine = rawLines[firstLineIndex + 2];
    //     if (thirdLine.contains("<")) {
    //       rawMrzLines.add(thirdLine);
    //     }
    //   }
    //   // log("\n${rawMrzLines.map((a)=>'$a\n${normalize44(a)}').join("\n")}");
    //   // log("-"*100);
    //   List<String> fixedMrzLines;
    //   if (rawMrzLines.length < 3) {
    //     if (rawMrzLines.first.length > 40) {
    //       type = DocumentStandardType.td3;
    //       format = MrzFormat.TD3;
    //
    //       fixedMrzLines = rawMrzLines.map((a) => normalize(a, len: 44)).toList();
    //     } else {
    //       type = DocumentStandardType.td2;
    //       format = MrzFormat.TD2;
    //       fixedMrzLines = rawMrzLines.map((a) => normalize(a, len: 36)).toList();
    //     }
    //   } else {
    //     format = MrzFormat.TD1;
    //     type = DocumentStandardType.td1;
    //     fixedMrzLines = rawMrzLines.map((a) => normalize(a, len: 30)).toList();
    //   }
    //   log("\n${fixedMrzLines.join("\n")}");
    //
    //   otherLines = [...rawLines].where((a) => !rawMrzLines.contains(a)).toList();
    //   if (fixedMrzLines.length < 2) return null;
    //   validation.linesLengthValid = true;
    //
    //   final firstLineFixed = fixedMrzLines.first;
    //   docCode = firstLineFixed.substring(0, 2);
    //   countryCode = firstLineFixed.substring(2, 5);
    //   issuing = firstLineFixed.substring(2, 5);
    //
    //   validation.docCodeValid = DocumentCodeHelper.isValid(docCode);
    //   validation.countryValid = isValidMrzCountry(countryCode);
    //
    //   if (!validation.countryValid) {
    //     log("country ${countryCode} is no valid");
    //   }
    //
    //   final secondLineFixed = fixedMrzLines[1];
    //   final mrzDatesSex = RegExp(r'(\d{6})(\d)([MFX<])(\d{6})(\d)', caseSensitive: false);
    //   final dateSexMatch = mrzDatesSex.firstMatch(secondLineFixed);
    //   if (dateSexMatch != null) {
    //     final birthDateStr = dateSexMatch.group(1);
    //     final birthCheck = dateSexMatch.group(2);
    //     final sexStr = dateSexMatch.group(3);
    //     final expiryDateStr = dateSexMatch.group(4);
    //     final expiryCheck = dateSexMatch.group(5);
    //
    //     validation.birthDateValid = _computeMrzCheckDigit(birthDateStr!) == birthCheck;
    //     validation.expiryDateValid = _computeMrzCheckDigit(expiryDateStr!) == expiryCheck;
    //     birthDate = _parseMrzDate(birthDateStr);
    //     expiryDate = _parseMrzDate(expiryDateStr);
    //     sex = sexStr;
    //   }
    //
    //   if (type == DocumentStandardType.td3) {
    //     final td3DocNumber = RegExp(r'^([A-Z0-9<]{9})(\d)', caseSensitive: false);
    //     final td3DocNumberMatch = td3DocNumber.firstMatch(secondLineFixed);
    //     if (td3DocNumberMatch != null) {
    //       final docNumberStr = td3DocNumberMatch.group(1);
    //       final docNumberCheckStr = td3DocNumberMatch.group(2);
    //       docNumber = docNumberStr;
    //       validation.docNumberValid = _computeMrzCheckDigit(docNumberStr ?? '') == docNumberCheckStr;
    //
    //       finalCheckValue += docNumberStr ?? '';
    //       finalCheckValue += docNumberCheckStr ?? '';
    //     }
    //
    //     final td3Nationality = RegExp(r'^[A-Z0-9<]{10}([A-Z0-9<]{3})', caseSensitive: false);
    //     final td3NationalityMatch = td3Nationality.firstMatch(secondLineFixed);
    //     if (td3NationalityMatch != null) {
    //       final nationalityStr = fixAlphaOnlyField(td3NationalityMatch.group(1)!);
    //       // log("nationalityStr ${nationalityStr}");
    //       nationality = nationalityStr;
    //       validation.nationalityValid = isValidMrzCountry(nationalityStr ?? '');
    //     } else {
    //       // log("td3NationalityMatch no match");
    //     }
    //
    //     if (!validation.docNumberValid) {
    //       final oldFixes = parseOldNumNat(secondLineFixed);
    //       if (oldFixes.length == 2) {
    //         docNumber = oldFixes[0];
    //         nationality = oldFixes[1];
    //         validation.docNumberValid = true;
    //         validation.nationalityValid = true;
    //       }
    //     }
    //
    //     if (dateSexMatch != null) {
    //       finalCheckValue += stripSexFromDateSex(dateSexMatch.group(0)!);
    //     }
    //
    //     final td3OptionalFinal = RegExp(r'^.{28}([A-Z0-9<]{15})(\d)$', caseSensitive: false);
    //     final td3OptionalFinalMatch = td3OptionalFinal.firstMatch(secondLineFixed);
    //
    //     if (td3OptionalFinalMatch != null) {
    //       final optionalStr = td3OptionalFinalMatch.group(1);
    //       final finalCheckStr = td3OptionalFinalMatch.group(2);
    //
    //       optional = optionalStr;
    //       finalCheckValue += (optionalStr ?? '');
    //
    //       validation.personalNumberValid = true;
    //       validation.hasFinalCheck = true;
    //       validation.finalCheckValid = _computeMrzCheckDigit(finalCheckValue) == finalCheckStr;
    //     }
    //
    //     name = parseNamesTd3OrTd2(firstLineFixed);
    //   } else if (type == DocumentStandardType.td2) {
    //     // Doc number + check (pos 0..8, 9)
    //     final td2DocNumber = RegExp(r'^([A-Z0-9<]{9})(\d)', caseSensitive: false);
    //     final td2DocNumberMatch = td2DocNumber.firstMatch(secondLineFixed);
    //     if (td2DocNumberMatch != null) {
    //       final docNumberStr = td2DocNumberMatch.group(1);
    //       final docNumberCheckStr = td2DocNumberMatch.group(2);
    //       docNumber = docNumberStr;
    //       validation.docNumberValid = _computeMrzCheckDigit(docNumberStr ?? '') == docNumberCheckStr;
    //
    //       finalCheckValue += (docNumberStr ?? '');
    //       finalCheckValue += (docNumberCheckStr ?? '');
    //     }
    //
    //     // Nationality (pos 10..12)
    //     final td2Nationality = RegExp(r'^[A-Z0-9<]{10}([A-Z<]{3})', caseSensitive: false);
    //     final td2NationalityMatch = td2Nationality.firstMatch(secondLineFixed);
    //     if (td2NationalityMatch != null) {
    //       final nationalityStr = fixAlphaOnlyField(td2NationalityMatch.group(1)!);
    //       nationality = nationalityStr;
    //       validation.nationalityValid = isValidMrzCountry(nationalityStr ?? '');
    //       finalCheckValue += nationalityStr!;
    //     }
    //
    //     // Dates + sex (pos 13..27)
    //     if (dateSexMatch != null) {
    //       finalCheckValue += dateSexMatch.group(0)!;
    //     }
    //
    //     // Optional (7) + final check (1) (pos 28..34, 35)
    //     final td2OptionalFinal = RegExp(r'^.{28}([A-Z0-9<]{7})(\d)$', caseSensitive: false);
    //     final td2OptionalFinalMatch = td2OptionalFinal.firstMatch(secondLineFixed);
    //
    //     if (td2OptionalFinalMatch != null) {
    //       final optionalStr = td2OptionalFinalMatch.group(1);
    //       final finalCheckStr = td2OptionalFinalMatch.group(2);
    //
    //       if (docCode.startsWith("V")) {
    //         validation.hasFinalCheck = true;
    //         validation.personalNumberValid = true;
    //         validation.finalCheckValid = true;
    //       } else {
    //         optional = optionalStr;
    //         finalCheckValue += (optionalStr ?? '');
    //         validation.personalNumberValid = true; // treat optional as personal no.
    //         validation.hasFinalCheck = true;
    //         validation.finalCheckValid = _computeMrzCheckDigit(finalCheckValue) == finalCheckStr;
    //       }
    //     }
    //
    //     name = parseNamesTd3OrTd2(firstLineFixed);
    //   } else if (type == DocumentStandardType.td1) {
    //     docNumber = firstLineFixed.substring(5, 14);
    //     final docNumberCheck = firstLineFixed[14];
    //     validation.docNumberValid = _computeMrzCheckDigit(docNumber) == docNumberCheck;
    //
    //     finalCheckValue += firstLineFixed.substring(5, 30);
    //
    //     // Dates + sex first (pos 0..14)
    //     if (dateSexMatch != null) {
    //       finalCheckValue += stripSexFromDateSex(dateSexMatch.group(0)!);
    //     }
    //
    //     // Nationality (pos 15..17)
    //     final td1Nationality = RegExp(r'^.{15}([A-Z<]{3})', caseSensitive: false);
    //     final td1NationalityMatch = td1Nationality.firstMatch(secondLineFixed);
    //     if (td1NationalityMatch != null) {
    //       final nationalityStr = fixAlphaOnlyField(td1NationalityMatch.group(1)!);
    //       nationality = nationalityStr;
    //       validation.nationalityValid = isValidMrzCountry(nationalityStr ?? '');
    //     }
    //
    //     // Optional (11) + final check (1) (pos 18..28, 29)
    //     final td1OptionalFinal = RegExp(r'^.{18}([A-Z0-9<]{11})(\d)$', caseSensitive: false);
    //     final td1OptionalFinalMatch = td1OptionalFinal.firstMatch(secondLineFixed);
    //
    //     if (td1OptionalFinalMatch != null) {
    //       final optionalStr = td1OptionalFinalMatch.group(1);
    //       final finalCheckStr = td1OptionalFinalMatch.group(2);
    //
    //       optional = optionalStr;
    //
    //       final natMatch = RegExp(r'^.{15}([A-Z<]{3})', caseSensitive: false).firstMatch(secondLineFixed);
    //       final nationalityForFinal = natMatch?.group(1) ?? '';
    //
    //       finalCheckValue += (optionalStr ?? ''); // positions 18..28
    //       validation.personalNumberValid = true;
    //       validation.hasFinalCheck = true;
    //       validation.finalCheckValid = _computeMrzCheckDigit(finalCheckValue) == finalCheckStr;
    //     }
    //     String nameLine = fixedMrzLines.last;
    //     name = parseNamesTd1(nameLine);
    //   }
    //
    //   if (name != null) {
    //     firstName = name.givenNames.join(" ");
    //     lastName = name.surname;
    //     validation.nameValid = name.validateNames(otherLines,OcrMrzSetting(nameValidationMode: NameValidationMode.exact),[]);
    //   }
    //
    //   log(validation.toString());
    //   log("-" * 100);
    //
    //   OcrMrzResult result = OcrMrzResult(
    //     line1: firstLineFixed,
    //     line2: secondLineFixed,
    //     format: format,
    //     documentCode: docCode,
    //     documentType: type.name.toUpperCase(),
    //     mrzFormat: format,
    //     countryCode: fixExceptionalCountry(countryCode),
    //     issuingState: fixExceptionalCountry(issuing),
    //     lastName: lastName ?? '',
    //     firstName: firstName ?? '',
    //     documentNumber: docNumber ?? '',
    //     nationality: fixExceptionalCountry(nationality ?? ''),
    //     birthDate: birthDate,
    //     expiryDate: expiryDate,
    //     sex: sex ?? '',
    //     personalNumber: optional ?? '',
    //     optionalData: optional ?? '',
    //     valid: validation,
    //     checkDigits: CheckDigits(document: true, birth: true, expiry: true, optional: true),
    //     ocrData: ocr,
    //   );
    //   mrzLogger?.call(OcrMrzLog(rawText: ocr.text, rawMrzLines: rawMrzLines, fixedMrzLines: fixedMrzLines, validation: validation, extractedData: result.toJson()));
    //   return result;
    // } else {
    //   // log("No Ocr");
    // }
    // return null;
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
}
