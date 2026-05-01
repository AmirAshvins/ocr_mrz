import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';
import 'package:ocr_mrz/aggregator.dart';
import 'package:ocr_mrz/doc_code_validator.dart';
import 'package:ocr_mrz/my_name_handler.dart';
import 'package:ocr_mrz/name_validation_data_class.dart';
import 'package:ocr_mrz/ocr_mrz_settings_class.dart';
import 'package:ocr_mrz/session_logger.dart';
import 'package:ocr_mrz/travel_doc_util.dart';

final _dateSexRe = RegExp(r'(\d{6})(\d)([MFX])(\d{6})(\d)', caseSensitive: false);

class SessionOcrHandlerConsensus {
  final SessionLogger logger;

  SessionOcrHandlerConsensus({required this.logger});

  OcrMrzConsensus handleSession(OcrMrzAggregator aggregator, OcrData ocr, OcrMrzSetting setting, List<NameValidationData> names) {
    try {
      final rawOcrText = ocr.text.replaceAll('\n', ' ');
      final rawOcrTextMultiLine = ocr.text;
      var updatedSession = aggregator.buildStatus();
      if ((updatedSession.step ?? 0) > 0) {
        if (!ocr.text.contains("<")) {
          return aggregator.build();
        }
      }
      final consensus = aggregator.build();
      logger.log(message: "--- New OCR Frame ---", step: updatedSession.step, details: {'ocr_text': rawOcrTextMultiLine, 'consensus': consensus.toJson(includeHistograms: true)});
      final List<String> lines = ocr.lines.map((a) => a.text).toList();
      aggregator.addFrameLines(lines);
      updatedSession = aggregator.buildStatus();
      logger.log(message: "Current Step: ${updatedSession.step}", step: updatedSession.step, details: {'ocr_text': rawOcrTextMultiLine, 'consensus': consensus.toJson(includeHistograms: true)});

      String secondLineGuess = lines.firstWhere((a) => _dateSexRe.hasMatch(a), orElse: () => '');
      if (secondLineGuess.isNotEmpty) {
        final dateSexMatch = _dateSexRe.firstMatch(secondLineGuess);
        final birthDateStr = dateSexMatch!.group(1);
        final birthCheck = dateSexMatch.group(2);
        final sexStr = dateSexMatch.group(3);
        final expiryDateStr = dateSexMatch.group(4);
        final expiryCheck = dateSexMatch.group(5);

        final calculatedBirthCheck = _computeMrzCheckDigit(birthDateStr!);
        final calculatedExpiryCheck = _computeMrzCheckDigit(expiryDateStr!);

        bool birthDateValid = calculatedBirthCheck == birthCheck;
        bool expDateValid = calculatedExpiryCheck == expiryCheck;
        bool sexValid = ["M", "F", "X", "<"].contains(sexStr);
        if ((updatedSession.step ?? 0) < 2) {
          logger.log(
            message: "Date/Sex Validation",
            step: updatedSession.step,
            details: {
              'birthDate': {'value': birthDateStr, 'checkDigit': birthCheck, 'calculated': calculatedBirthCheck, 'valid': birthDateValid},
              'expiryDate': {'value': expiryDateStr, 'checkDigit': expiryCheck, 'calculated': calculatedExpiryCheck, 'valid': expDateValid},
              'sex': {'value': sexStr, 'valid': sexValid},
              'line': secondLineGuess,
              'ocr_text': rawOcrTextMultiLine,
              'consensus': consensus.toJson(includeHistograms: true),
            },
          );
        }

        var currentVal = aggregator.validation;
        currentVal.birthDateValid = birthDateValid;
        currentVal.expiryDateValid = expDateValid;
        currentVal.sexValid = sexValid;
        aggregator.validation = currentVal;

        if (birthDateValid && expDateValid) {
          if (aggregator.buildStatus().birthDate != birthDateStr) {
            logger.log(
              message: "New birth date detected. Resetting session.",
              step: updatedSession.step,
              details: {'new_birth_date': birthDateStr, 'old_birth_date': aggregator.buildStatus().birthDate, 'ocr_text': rawOcrTextMultiLine, 'consensus': consensus.toJson(includeHistograms: true)},
            );
            aggregator.reset();
          }
          aggregator.addBirthDate(birthDateStr);
          aggregator.addExpiryDate(expiryDateStr);
          aggregator.addExpCheck(expiryCheck!);
          aggregator.addBirthCheck(birthCheck!);
          aggregator.addSex(sexStr!);
          if ((updatedSession.step ?? 0) < 2) {
            aggregator.setStep(2);
            logger.log(message: "Step updated to 2. Found valid birth and expiry dates.", step: 2, details: {'ocr_text': rawOcrTextMultiLine, 'consensus': consensus.toJson(includeHistograms: true)});
          }
        }
      } else {
        if ((updatedSession.step ?? 0) < 2) {
          logger.log(
            message: "RegExp search for date/sex line failed to find a match.",
            step: updatedSession.step,
            details: {'pattern': _dateSexRe.pattern, 'searched_lines': lines, 'ocr_text': rawOcrTextMultiLine, 'consensus': consensus.toJson(includeHistograms: true)},
          );
        }
      }

      updatedSession = aggregator.buildStatus();

      if (_dateSexRe.hasMatch(ocr.text)) {
        final dateSexMatchCheck = _dateSexRe.firstMatch(secondLineGuess);
        if (dateSexMatchCheck != null) {
          String dateSexCheckStr = dateSexMatchCheck.group(0)!;
          if (updatedSession.dateSexStr != dateSexCheckStr) {
            logger.log(
              message: "New document detected based on date/sex string change. Resetting session.",
              step: updatedSession.step,
              details: {'new_date_sex': dateSexCheckStr, 'old_date_sex': updatedSession.dateSexStr, 'ocr_text': rawOcrTextMultiLine, 'consensus': consensus.toJson(includeHistograms: true)},
            );
            aggregator.reset();
          }
        }
      }

      if ((aggregator.buildStatus().step ?? 0) >= 2) {
        if (aggregator.buildStatus().step == 2) {
          logger.log(
            message: "Attempting to find nationality (Step 2->3)",
            step: updatedSession.step,
            details: {'ocr_text': rawOcrTextMultiLine, 'consensus': consensus.toJson(includeHistograms: true)},
          );
        }
        String? type;
        final parts = updatedSession.dateSexStr!.split(RegExp(r'[^0-9]+'));
        String? nationalityStr;
        String birth = parts[0];
        String exp = parts[1];
        final countryBeforeBirthReg = RegExp(r'([A-Za-z0-9]{3})(?=' + RegExp.escape(birth) + r')');
        final countryAfterExpReg = RegExp(RegExp.escape(exp) + r'([A-Za-z]{3})');
        String line1 = "";
        String? line3;
        for (var l in lines) {
          int index = lines.indexOf(l);
          l = normalize(l);
          final countryBeforeBirthMatch = countryBeforeBirthReg.firstMatch(l);
          if (countryBeforeBirthMatch != null) {
            type = l.length < 40 ? "td2" : "td2";
            nationalityStr = countryBeforeBirthMatch.group(0)!;
            if (index != 0) line1 = lines[index - 1];
          } else if (l.contains(birth)) {
            String beforeBirth = l.split(birth).first;
            if (beforeBirth.length > 2) {
              nationalityStr = beforeBirth.substring(beforeBirth.length - 3);
              type = l.length < 40 ? "td2" : "td3";
              if (index != 0) line1 = lines[index - 1];
            }
          }

          if (nationalityStr == null) {
            final countryAfterExpMatch = countryAfterExpReg.firstMatch(l);
            if (countryAfterExpMatch != null) {
              type = "td1";
              nationalityStr = countryAfterExpMatch.group(1)!;
              if (index != 0) line1 = lines[index - 1];
              if (index != lines.length - 1) line3 = lines[index + 1];
            }
          }

          if (nationalityStr != null) {
            final fixedNationalityStr = fixAlphaOnlyField(nationalityStr);
            bool isCountryValid = isValidMrzCountry(nationalityStr) || isValidMrzCountry(fixedNationalityStr);
            if ((updatedSession.step ?? 0) < 3) {
              logger.log(
                message: "Potential nationality found",
                step: updatedSession.step,
                details: {'nationality': nationalityStr, 'valid': isCountryValid, 'line': l, 'ocr_text': rawOcrTextMultiLine, 'consensus': consensus.toJson(includeHistograms: true)},
              );
            }

            if (isCountryValid) {
              var currentVal = aggregator.validation;
              currentVal.nationalityValid = true;
              aggregator.addNationality(nationalityStr);
              aggregator.validation = currentVal;
              aggregator.setType(type);
              if ((updatedSession.step ?? 0) < 3) {
                aggregator.setStep(3);
                logger.log(
                  message: "Step updated to 3. Nationality confirmed.",
                  step: 3,
                  details: {'nationality': nationalityStr, 'type': type, 'ocr_text': rawOcrTextMultiLine, 'consensus': consensus.toJson(includeHistograms: true)},
                );
                updatedSession = updatedSession.copyWith(step: 3, nationality: nationalityStr, type: type, line1: line1, line2: l, line3: line3, validation: currentVal);
              }
              break;
            }
          }
        }
        if (nationalityStr == null) {
          if ((updatedSession.step ?? 0) < 3) {
            logger.log(
              message: "Could not find a valid nationality.",
              step: updatedSession.step,
              details: {'birth_date': birth, 'expiry_date': exp, 'ocr_text': rawOcrTextMultiLine, 'consensus': consensus.toJson(includeHistograms: true)},
            );
          }
        }
      }
      updatedSession = aggregator.buildStatus();
      if ((aggregator.buildStatus().step ?? 0) >= 3) {
        if (aggregator.buildStatus().step == 3) {
          logger.log(
            message: "Attempting to find document number (Step 3->4)",
            step: updatedSession.step,
            details: {'ocr_text': rawOcrTextMultiLine, 'consensus': consensus.toJson(includeHistograms: true)},
          );
        }
        String? numberStr;
        if (updatedSession.type == "td1") {
          // TD1 logic
        } else {
          final natOnly = "${updatedSession.nationality}";
          final numberBeforeNatReg = RegExp(r'([A-Z0-9<]{9,12})(\d)(?=' + RegExp.escape(natOnly) + r')');
          for (var l in lines) {
            int index = lines.indexOf(l);
            var numberBeforeNatMatch = numberBeforeNatReg.firstMatch(normalize(l)) ?? numberBeforeNatReg.firstMatch(fixOcrBeforeNatOnly(l, natOnly));

            if (numberBeforeNatMatch != null && index != 0) {
              numberStr = numberBeforeNatMatch.group(1)!.replaceAll("O", '0').replaceAll("<", '');
              String numberStrCheck = numberBeforeNatMatch.group(2)!;
              final calculatedDocNumberCheck = _computeMrzCheckDigit(numberStr);
              bool docNumberValid = calculatedDocNumberCheck == numberStrCheck;
              if ((updatedSession.step ?? 0) < 4) {
                logger.log(
                  message: "Potential document number found => $numberStr",
                  step: updatedSession.step,
                  details: {
                    'doc_number': numberStr,
                    'checkDigit': numberStrCheck,
                    'calculated': calculatedDocNumberCheck,
                    'valid': docNumberValid,
                    'line': l,
                    'ocr_text': rawOcrTextMultiLine,
                    'consensus': consensus.toJson(includeHistograms: true),
                  },
                );
              }

              var currentVal = aggregator.validation;
              currentVal.docNumberValid = docNumberValid;

              String firstLineGuess = lines[index - 1];
              if (firstLineGuess.length > 5) {
                String docCode = firstLineGuess.substring(0, 2);
                String countryCode = firstLineGuess.substring(2, 5);
                bool validCode = DocumentCodeHelper.isValid(docCode);
                bool validCountry = isValidMrzCountry(countryCode);
                if ((updatedSession.step ?? 0) < 4) {
                  logger.log(
                    message: "Header validation",
                    step: updatedSession.step,
                    details: {
                      'docCode': docCode,
                      'docCodeValid': validCode,
                      'country': countryCode,
                      'countryValid': validCountry,
                      'ocr_text': rawOcrTextMultiLine,
                      'consensus': consensus.toJson(includeHistograms: true),
                    },
                  );
                }
                if (validCode && validCountry) {
                  currentVal.countryValid = validCountry;
                  currentVal.docCodeValid = validCode;

                  if (docNumberValid) {
                    aggregator.addDocNum(numberStr);
                    aggregator.addNumCheck(numberStrCheck);
                    if ((updatedSession.step ?? 0) < 4) {
                      aggregator.setStep(4);
                      logger.log(message: "Step updated to 4. Document number confirmed.", step: 4, details: {'ocr_text': rawOcrTextMultiLine, 'consensus': consensus.toJson(includeHistograms: true)});
                    }
                  }
                  aggregator.addDocCode(docCode);
                  aggregator.addCountry(countryCode);
                }
              }
            }
          }
          if (numberStr == null) {
            if ((updatedSession.step ?? 0) < 4) {
              logger.log(
                message: "RegExp search for document number failed to find a match.",
                step: updatedSession.step,
                details: {
                  'pattern': numberBeforeNatReg.pattern,
                  'searched_lines': lines.map((l) => normalize(l)).toList(),
                  'ocr_text': rawOcrTextMultiLine,
                  'consensus': consensus.toJson(includeHistograms: true),
                },
              );
            }
          }
        }
      }

      updatedSession = aggregator.buildStatus();
      if ((aggregator.buildStatus().step ?? 0) >= 4) {
        if (aggregator.buildStatus().step == 4) {
          logger.log(
            message: "Attempting to find and validate names (Step 4->5)",
            step: updatedSession.step,
            details: {'ocr_text': rawOcrTextMultiLine, 'consensus': consensus.toJson(includeHistograms: true)},
          );
        }
        if (updatedSession.type == "td1") {
          // TD1 name logic
        } else {
          String line1Start = updatedSession.docCode! + updatedSession.countryCode!;
          for (var l in lines) {
            if (l.startsWith(line1Start)) {
              MrzName name = parseNamesTd3OrTd2(l);
              if ((updatedSession.step ?? 0) < 5) {
                logger.log(
                  message: "Parsed Names",
                  step: updatedSession.step,
                  details: {'surname': name.surname, 'givenNames': name.givenNames.join(' '), 'ocr_text': rawOcrTextMultiLine, 'consensus': consensus.toJson(includeHistograms: true)},
                );
              }
              List<String> otherLines = [...lines.where((a) => a != l)];
              var currentVal = aggregator.validation;
              final (isValid, validationSource, fixed) = name.validateNames(otherLines, setting, names);
              if (isValid) {
                logger.log(
                  message: "FIXED VALID NAME: ${fixed.full} source ${validationSource}",
                  step: updatedSession.step,
                  details: {
                    'source': validationSource,
                    'parsed_surname': name.surname,
                    'parsed_given_names': name.givenNames,
                    'lookup_lines': otherLines,
                    'ocr_text': rawOcrTextMultiLine,
                    'consensus': consensus.toJson(includeHistograms: true),
                  },
                );
              }
              name = fixed;
              currentVal.nameValid = isValid;
              aggregator.validation = currentVal;
              if ((updatedSession.step ?? 0) < 5) {
                logger.log(
                  message: "Name validation result: $isValid Looking for ${name.surname}| ${name.givenNames.join(" ")} in\n ${otherLines.join("\n")}",
                  step: updatedSession.step,
                  details: {
                    'source': validationSource,
                    'parsed_surname': name.surname,
                    'parsed_given_names': name.givenNames,
                    'lookup_lines': otherLines,
                    'ocr_text': rawOcrTextMultiLine,
                    'consensus': consensus.toJson(includeHistograms: true),
                  },
                );
              }

              if (!currentVal.nameValid) {
                if ((updatedSession.step ?? 0) < 3) {
                  logger.log(
                    message: "Validation failed: Name validation failed. Looking for ${name.surname} ${name.givenNames.join(" ")} in\n ${otherLines.join("\n")}",
                    step: updatedSession.step,
                    details: {'source': validationSource, 'ocr_text': rawOcrTextMultiLine, 'consensus': consensus.toJson(includeHistograms: true)},
                  );
                }
              }

              if (currentVal.nameValid) {
                aggregator.addFirstName(name.givenNames.join(" "));
                aggregator.addLastName(name.surname);
                if ((updatedSession.step ?? 0) < 5) {
                  aggregator.setStep(5);
                  logger.log(message: "Step updated to 5. Name confirmed.", step: 5, details: {'ocr_text': rawOcrTextMultiLine, 'consensus': consensus.toJson(includeHistograms: true)});
                }
              }
            }
          }
        }
      }

      final finalConsensus = aggregator.build();
      if ((aggregator.buildStatus().step ?? 0) >= 5) {
        logger.log(
          message: "Finalizing session check.",
          step: aggregator.buildStatus().step,
          details: {'status': aggregator.buildStatus().toString(), 'consensus': finalConsensus.toJson(includeHistograms: true), 'ocr_text': rawOcrTextMultiLine},
        );
      }
      return finalConsensus;
    } catch (e, st) {
      logger.log(
        message: "!!! An error occurred in handleSession !!!",
        details: {'error': e.toString(), 'stackTrace': st.toString(), 'ocr_text': ocr.text.replaceAll('\n', ' '), 'consensus': aggregator.build().toJson(includeHistograms: true)},
      );
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
    while (b.length < len) {
      b.write('<');
    }
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

String fixAlphaOnlyField(String value) {
  final map = {'0': 'O', '1': 'I', '5': 'S', '8': 'B', '6': 'G'};
  return value.toUpperCase().split('').map((c) => map[c] ?? c).join();
}

String fixOcrBeforeNatOnly(String input, String natOnly) {
  if (natOnly.isEmpty) return input;

  const Map<String, String> map = {'O': '0', 'Q': '0', 'D': '0', 'I': '1', 'L': '1', 'Z': '2', 'S': '5', 'B': '8', 'G': '6', 'T': '7'};

  bool isTokenChar(int codeUnit) {
    final c = String.fromCharCode(codeUnit);
    final isAZ = codeUnit >= 65 && codeUnit <= 90;
    final is09 = codeUnit >= 48 && codeUnit <= 57;
    return isAZ || is09 || c == '<';
  }

  String replaceInToken(String token) {
    final sb = StringBuffer();
    for (var i = 0; i < token.length; i++) {
      final ch = token[i];
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }

  final upper = input.toUpperCase();
  final sb = StringBuffer();

  int searchFrom = 0;
  while (true) {
    final idx = upper.indexOf(natOnly, searchFrom);
    if (idx == -1) {
      sb.write(upper.substring(searchFrom));
      break;
    }

    int tokenEnd = idx;
    int tokenStart = tokenEnd;
    while (tokenStart > 0 && isTokenChar(upper.codeUnitAt(tokenStart - 1))) {
      tokenStart--;
    }

    sb.write(upper.substring(searchFrom, tokenStart));
    final token = upper.substring(tokenStart, tokenEnd);
    sb.write(replaceInToken(token));
    sb.write(natOnly);

    searchFrom = idx + natOnly.length;
  }

  return sb.toString();
}
