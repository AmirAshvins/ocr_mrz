import 'dart:developer';

import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';
import 'package:ocr_mrz/doc_code_validator.dart';
import 'package:ocr_mrz/mrz_result_class_fix.dart';
import 'package:ocr_mrz/my_name_handler.dart';
import 'package:ocr_mrz/session_status_class.dart';
import 'package:ocr_mrz/travel_doc_util.dart';

import 'ocr_mrz_settings_class.dart';

final _dateSexRe = RegExp(r'(\d{6})(\d)([MFX])(\d{6})(\d)', caseSensitive: false);

class SessionOcrHandler {
  SessionStatus handleSession(SessionStatus session, OcrData ocr) {
    try {
      final List<String> lines = ocr.lines.map((a) => a.text).toList();
      final List<String> baseLines = List<String>.of(ocr.lines.map((a) => a.text).toList());
      SessionStatus updatedSession = session;

      if (updatedSession.step == 0) {
        updatedSession = updatedSession.copyWith(step: 1, dateTime: DateTime.now(), details: "Looking for BirthGenderExp", ocr: ocr);
      }
      // log("handleSession ${updatedSession.step}");
      if (updatedSession.step == 1) {
        String secondLineGuess = lines.firstWhere((a) => _dateSexRe.hasMatch(a), orElse: () => '');
        if (secondLineGuess.isNotEmpty) {
          final dateSexMatch = _dateSexRe.firstMatch(secondLineGuess);
          String dateSexStr = dateSexMatch!.group(0)!;
          final birthDateStr = dateSexMatch.group(1);
          final birthCheck = dateSexMatch.group(2);
          final sexStr = dateSexMatch.group(3);
          final expiryDateStr = dateSexMatch.group(4);
          final expiryCheck = dateSexMatch.group(5);
          bool birthDateValid = _computeMrzCheckDigit(birthDateStr!) == birthCheck;
          bool expDateValid = _computeMrzCheckDigit(expiryDateStr!) == expiryCheck;
          bool sexValid = ["M", "F", "X", "<"].contains(sexStr);

          var currentVal = updatedSession.validation ?? OcrMrzValidation();
          currentVal.birthDateValid = birthDateValid;
          currentVal.expiryDateValid = expDateValid;
          currentVal.sexValid = sexValid;
          if (birthDateValid && expDateValid) {
            updatedSession = updatedSession.copyWith(
              step: 2,
              details: "Found Dates and Gender",
              validation: currentVal,
              birthDate: birthDateStr,
              expiryDate: expiryDateStr,
              sex: sexStr,
              dateSexStr: dateSexStr,
              line2: secondLineGuess,
              birthCheck: birthCheck,
              expCheck: expiryCheck,
              logDetails: "Found Valid Birth Sex Gender => $dateSexStr",
            );
          } else {
            updatedSession = updatedSession.copyWith(
              step: 1,
              details: "Looking for valid Dates",
              validation: currentVal,
              birthDate: birthDateStr,
              expiryDate: expiryDateStr,
              sex: sexStr,
              dateSexStr: dateSexStr,
              line2: secondLineGuess,
              birthCheck: birthCheck,
              expCheck: expiryCheck,
              logDetails: "Found Invalid Birth Sex Gender => $dateSexStr",
            );
          }
        }
      }
      if (updatedSession.step == 2) {
        String? type;
        final parts = updatedSession.dateSexStr!.split(RegExp(r'[^0-9]+'));
        String? nationalityStr;
        String birth = parts[0];
        String exp = parts[1];
        // log("look before $birth or after $exp  ${updatedSession.line2??''}");
        // final countryBeforeBirthReg = RegExp(r'[A-Za-z]{3}' + birth);
        final countryBeforeBirthReg = RegExp(r'([A-Za-z0-9]{3})(?=' + RegExp.escape(birth) + r')');
        final countryAfterExpReg = RegExp(RegExp.escape(exp) + r'([A-Za-z]{3})');
        String line1 = "";
        String? line3;
        for (var l in lines) {
          int index = lines.indexOf(l);
          l = normalize(l);
          final countryBeforeBirthMatch = countryBeforeBirthReg.firstMatch(normalize(l));
          if (countryBeforeBirthMatch != null) {
            // log("we have before ${countryBeforeBirthMatch.group(0)}");
            type = l.length < 40 ? "td2" : "td3";
            nationalityStr = countryBeforeBirthMatch.group(0)!;
            if (index != 0) {
              line1 = lines[index - 1];
            }
            updatedSession = updatedSession.copyWith(logDetails: "Found Valid Nationality ${nationalityStr} in ${countryBeforeBirthMatch.group(0)}$birth");
          }
          final countryAfterExpMatch = countryAfterExpReg.firstMatch(normalize(l));
          if (countryAfterExpMatch != null && normalize(l).startsWith(birth)) {
            // log("we have match after ${countryAfterExpMatch.group(1)}");
            type = "td1";
            nationalityStr = countryAfterExpMatch.group(1)!;
            if (index != 0) {
              line1 = lines[index - 1];
            }
            if (index != lines.length - 1) {
              line3 = lines[index + 1];
            }
            updatedSession = updatedSession.copyWith(logDetails: "Found Valid Nationality ${nationalityStr} in $exp${countryAfterExpMatch.group(0)}");
          } else {
            // log("not countryAfterExpReg ${normalize(l)}");
          }

          if (nationalityStr != null) {
            final fixedNationalityStr = fixAlphaOnlyField(nationalityStr);
            if (isValidMrzCountry(nationalityStr) || isValidMrzCountry(fixedNationalityStr)) {
              var currentVal = updatedSession.validation ?? OcrMrzValidation();
              currentVal.nationalityValid = isValidMrzCountry(nationalityStr) || isValidMrzCountry(fixedNationalityStr);
              updatedSession = updatedSession.copyWith(
                step: 3,
                details: 'Found nationality',
                nationality: nationalityStr,
                type: type,
                line1: line1,
                line2: normalize(l),
                line3: line3,
                validation: currentVal,
              );
            }

            // final fixedNationalityStr = fixAlphaOnlyField(nationalityStr);
            if (isValidMrzCountry(nationalityStr)) {
              var currentVal = updatedSession.validation ?? OcrMrzValidation();
              currentVal.nationalityValid = isValidMrzCountry(nationalityStr);
              updatedSession = updatedSession.copyWith(
                step: 3,
                details: 'Found nationality',
                nationality: nationalityStr,
                type: type,
                line1: line1,
                line2: normalize(l),
                line3: line3,
                validation: currentVal,
              );
            }
          } else {
            updatedSession = updatedSession.copyWith(
              logDetails: "Did not found valid Nationality before $birth or after $exp in\n${lines.where((a) => a.contains(birth) || a.contains(exp)).map((b) => normalize(b)).join("\n")}",
            );
            // log("not valid nat ${nationalityStr} in ${lines.map((a) => normalize(a)).join("\n")}");
          }
        }
      }

      if (updatedSession.step == 3) {
        String? numberStr;
        if (updatedSession.type == "td1") {
          String dateStart = updatedSession.birthDate!;
          for (var l in lines) {
            int index = lines.indexOf(l);
            if (l.startsWith(dateStart)) {
              // log("we have before ${countryBeforeBirthMatch.group(0)}");
              // numberStr = numberBeforeNatMatch.group(1)!.replaceAll("O", '0').replaceAll("<", '');
              // String numberStrCheck = numberBeforeNatMatch.group(2)!;
              // bool docNumberValid = _computeMrzCheckDigit(numberStr!) == numberStrCheck;
              // currentVal.docNumberValid = docNumberValid;

              var currentVal = updatedSession.validation!;

              String firstLineGuess = normalize(lines[index - 1]);
              if (firstLineGuess.length >= 15) {
                String firstFiveChars = firstLineGuess.substring(0, 5);
                String docCode = firstFiveChars.substring(0, 2);
                String countryCode = firstFiveChars.substring(2, 5);
                bool validCode = DocumentCodeHelper.isValid(docCode);
                log("valid code ${validCode} ==> ${docCode}");
                bool validCountry = isValidMrzCountry(countryCode);
                if (validCode && validCountry) {
                  numberStr = firstLineGuess.substring(5, 14);
                  final numberStrCheck = firstLineGuess[14];
                  bool validDocNumber = _computeMrzCheckDigit(numberStr) == numberStrCheck;

                  currentVal.countryValid = validCountry;
                  currentVal.docCodeValid = validCode;

                  updatedSession = updatedSession.copyWith(
                    step: 3,
                    line1: normalizeWithLength(normalize(firstLineGuess), len: 30),
                    line2: normalizeWithLength("${dateStart}${countryCode}", len: 30),
                    details: "Found Number Code Country : $numberStr",
                    countryCode: countryCode,
                    docCode: docCode,
                    validation: currentVal,
                    numberCheck: numberStrCheck,
                    logDetails: "Found valid $countryCode DocCode $docCode",
                  );

                  currentVal.docNumberValid = validDocNumber;
                  currentVal.linesLengthValid = true;
                  currentVal.finalCheckValid = true;
                  currentVal.personalNumberValid = true;
                  if (validDocNumber) {
                    updatedSession = updatedSession.copyWith(
                      step: 4,
                      line1: normalizeWithLength(normalize(firstLineGuess), len: 30),
                      line2: normalizeWithLength("${dateStart}${numberStr}${numberStrCheck}", len: 30),
                      details: "Found Number Code Country : $numberStr",
                      countryCode: countryCode,
                      docCode: docCode,
                      docNumber: numberStr,
                      validation: currentVal,
                      numberCheck: numberStrCheck,
                      logDetails: "Found valid Number: $numberStr Country: $countryCode DocCode $docCode",
                    );
                  } else {
                    // log("invalid doc number $numberStr checked $numberStrCheck\n${normalizeWithLength(normalize(firstLineGuess), len: 30)}");
                  }
                }
              }

              // log("numberStr $numberStr");
              // log("numberStrCheck $numberStrCheck");
            }

            // if (nationalityStr != null) {
            //   if (isValidMrzCountry(nationalityStr)) {
            //     var currentVal = updatedSession.validation ?? OcrMrzValidation();
            //     currentVal.nationalityValid = isValidMrzCountry(nationalityStr);
            //     updatedSession = updatedSession.copyWith(step: 3, details: 'Found nationality', nationality: nationalityStr, type: type, line1: line1, line2: normalize(l), line3: line3, validation: currentVal);
            //   }
            // }
          }
        } else {
          final parts = updatedSession.dateSexStr!.split(RegExp(r'[^0-9]+'));
          String birth = parts[0];
          String natBirth = "${updatedSession.nationality}$birth";
          String natOnly = "${updatedSession.nationality}";

          // final numberBeforeNatReg = RegExp(r'^(.*?)(?=' + RegExp.escape(natBirth) + r')');
          final numberBeforeNatReg = RegExp(r'([A-Z0-9<]{9,12})(\d)(?=' + RegExp.escape(natOnly) + r')');
          for (var l in lines) {
            int index = lines.indexOf(l);
            final numberBeforeNatMatch = numberBeforeNatReg.firstMatch(normalize(l));
            if (numberBeforeNatMatch != null && index != 0) {
              // log("we have before ${countryBeforeBirthMatch.group(0)}");
              numberStr = numberBeforeNatMatch.group(1)!.replaceAll("O", '0').replaceAll("<", '');
              String numberStrCheck = numberBeforeNatMatch.group(2)!;
              bool docNumberValid = _computeMrzCheckDigit(numberStr!) == numberStrCheck;
              var currentVal = updatedSession.validation!;
              currentVal.docNumberValid = docNumberValid;

              String firstLineGuess = lines[index - 1];
              if (firstLineGuess.length > 5) {
                String firstFiveChars = firstLineGuess.substring(0, 5);
                String docCode = firstFiveChars.substring(0, 2);
                String countryCode = firstFiveChars.substring(2, 5);
                bool validCode = DocumentCodeHelper.isValid(docCode);
                bool validCountry = isValidMrzCountry(countryCode);

                if (validCode && validCountry) {
                  currentVal.countryValid = validCountry;
                  currentVal.docCodeValid = validCode;
                  currentVal.finalCheckValid = true;
                  currentVal.personalNumberValid = true;
                  currentVal.linesLengthValid = true;
                  updatedSession = updatedSession.copyWith(
                    step: 4,
                    details: "Found Number Code Country : $numberStr",
                    line2: normalizeWithLength('${updatedSession.docNumber}${numberStrCheck}${updatedSession.dateSexStr}${updatedSession.optional ?? ''}', len: 44),
                    countryCode: countryCode,
                    docCode: docCode,
                    docNumber: numberStr,
                    validation: currentVal,
                    nationality: fixAlphaOnlyField(natOnly),
                    numberCheck: numberStrCheck,
                    logDetails: "Found valid Number: $numberStr Country: $countryCode DocCode $docCode",
                  );
                }
              }

              // log("numberStr $numberStr");
              // log("numberStrCheck $numberStrCheck");
            }

            // if (nationalityStr != null) {
            //   if (isValidMrzCountry(nationalityStr)) {
            //     var currentVal = updatedSession.validation ?? OcrMrzValidation();
            //     currentVal.nationalityValid = isValidMrzCountry(nationalityStr);
            //     updatedSession = updatedSession.copyWith(step: 3, details: 'Found nationality', nationality: nationalityStr, type: type, line1: line1, line2: normalize(l), line3: line3, validation: currentVal);
            //   }
            // }
          }
        }
      }

      // if (updatedSession.step == 4) {
      //   String? numberStr;
      //   if (updatedSession.type == DocumentStandardType.td1) {
      //   } else {
      //     for (var l in lines) {
      //       int index = lines.indexOf(l);
      //       if (l.startsWith(updatedSession.docNumber!) && index > 0) {
      //         String line1 = fixAlphaOnlyField(lines[index - 1]);
      //         if (line1.length > 13) {
      //           String firstFiveChars = line1.substring(0, 5);
      //           String docCode = firstFiveChars.substring(0, 2);
      //           String countryCode = firstFiveChars.substring(2, 5);
      //           bool validCode = DocumentCodeHelper.isValid(docCode);
      //           bool validCountry = isValidMrzCountry(countryCode);
      //           var currentVal = updatedSession.validation!;
      //           currentVal.countryValid = validCountry;
      //           currentVal.docCodeValid = validCode;
      //
      //           if (validCountry && validCode) {
      //             updatedSession = updatedSession.copyWith(step: 5, details: 'Found nationality', line1: normalize(line1), line2: l, countryCode: countryCode, docCode: docCode);
      //           }
      //         }
      //       }
      //     }
      //   }
      // }

      if (updatedSession.step == 4) {
        if (updatedSession.type == "td1") {
          if (lines.length > 2) {
            String line3 = lines[2];
            MrzName? name = parseNamesTd1(line3);
            String firstName = name.givenNames.join(" ");
            String lastName = name.surname;
            List<String> otherLines = [...lines.where((a) => a != line3).map((a) => normalize(a))];
            var currentVal = updatedSession.validation ?? OcrMrzValidation();
            var (a, _, __) = name.validateNames(otherLines, OcrMrzSetting(nameValidationMode: NameValidationMode.exact), []);
            currentVal.nameValid = a;
            updatedSession = updatedSession.copyWith(
              step: 5,
              details: 'Found names',
              line3: normalize(line3),
              firstName: firstName,
              lastName: lastName,
              validation: currentVal,
              logDetails: "Found Name: $firstName  $lastName",
            );
          }
        } else {
          String line1Start = updatedSession.docCode! + updatedSession.countryCode!;

          for (var l in lines) {
            if (l.startsWith(line1Start)) {
              MrzName? name = parseNamesTd3OrTd2(l);
              String firstName = name.givenNames.join(" ");
              String lastName = name.surname;
              List<String> otherLines = [...lines.where((a) => a != l).map((a) => normalize(a))];
              var currentVal = updatedSession.validation ?? OcrMrzValidation();
              var (a, _, __) = name.validateNames(otherLines, OcrMrzSetting(nameValidationMode: NameValidationMode.exact), []);
              currentVal.nameValid = a;
              updatedSession = updatedSession.copyWith(
                step: 5,
                details: 'Found names',
                line1: normalize(l),
                firstName: firstName,
                lastName: lastName,
                validation: currentVal,
                logDetails: "Found Name: $firstName  $lastName",
              );
            }
          }
        }
      }

      // if (updatedSession.step == 6) {
      //   if (updatedSession.type == DocumentStandardType.td1) {
      //   } else {
      //     final optionalAndFinalCheckReg = RegExp(r'^(.*?<+)(\d{0,2})$');
      //     // String datesSex = updatedSession.dateSexStr!;
      //     String expWithCheck = updatedSession.expiryDate! + updatedSession.expCheck!;
      //     for (var l in baseLines) {
      //       l = normalize(l);
      //       if (l.length > 20) {
      //         List<String> parts = l.split(expWithCheck);
      //         if (parts.length > 1) {
      //           String optionalAndFinalGuess = parts[1];
      //           final optionalAndFinalCheckMatch = optionalAndFinalCheckReg.firstMatch(optionalAndFinalGuess);
      //           if (optionalAndFinalCheckMatch != null) {
      //             String optionalStr = optionalAndFinalCheckMatch.group(1)!;
      //             String finalCheckStr = optionalAndFinalCheckMatch.group(2)!;
      //
      //             bool finalCheckValid = (updatedSession.getFinalCheckValue)==_computeMrzCheckDigit(finalCheckStr);
      //             var currentVal = updatedSession.validation!;
      //             currentVal.finalCheckValid = finalCheckValid;
      //             if(finalCheckValid) {
      //               updatedSession = updatedSession.copyWith(step: 7, details: 'Found Final Check', optional: optionalStr, finalCheck: finalCheckStr);
      //             }else{
      //               log("final check not valid ==> ${updatedSession.getFinalCheckValue} ${finalCheckStr}");
      //             }
      //
      //           }
      //         }
      //       }
      //     }
      //   }
      // }

      // log("${updatedSession.step} ${updatedSession.logDetails??''}");
      return updatedSession;
    } catch (e) {
      if (e is Error) {
        log("$e\n${e.stackTrace}");
      }
      rethrow;
    }
  }

  static String normalize(String line) {
    line = line.replaceAll(" ", '');
    line = line.replaceAll("«", "<<");
    final b = StringBuffer();
    for (final rune in line.toUpperCase().runes) {
      var ch = String.fromCharCode(rune);
      ch = _normMap[ch] ?? ch;
      final cu = ch.codeUnitAt(0);
      final isAZ = cu >= 65 && cu <= 90;
      final is09 = cu >= 48 && cu <= 57;
      if (isAZ || is09 || cu == 60) {
        b.writeCharCode(cu);
      }
    }
    return b.toString();
  }

  static String normalizeWithLength(String line, {int len = 44}) {
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

String fixAlphaOnlyField(String value) {
  final map = {'0': 'O', '1': 'I', '5': 'S', '8': 'B', '6': 'G'};
  return value.toUpperCase().split('').map((c) => map[c] ?? c).join();
}
