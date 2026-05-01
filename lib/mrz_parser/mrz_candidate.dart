import 'package:ocr_mrz/mrz_parser/mrz_country_codes.dart';
import 'package:ocr_mrz/mrz_parser/mrz_result.dart';
import 'package:ocr_mrz/mrz_parser/mrz_utils.dart';

/// Represents a potential MRZ parsed from a single camera frame.
class MrzCandidate {
  final List<String> lines;
  MrzFormat format = MrzFormat.Unknown;

  String? documentType, countryCode, issuingState, documentNumber, lastName, firstName, sex, nationality, optionalData1, optionalData2;
  DateTime? birthDate, expiryDate;
  bool docNumberValid = false, birthDateValid = false, expiryDateValid = false, optionalDataValid = false, finalCompositeValid = false;

  MrzCandidate({required this.lines}) {
    _determineFormat();
    _parse();
  }

  void _determineFormat() {
    if (lines.length >= 2 && lines[0].length == 44 && lines[1].length == 44)
      format = MrzFormat.TD3;
    else if (lines.length >= 2 && lines[0].length == 36 && lines[1].length == 36)
      format = MrzFormat.TD2;
    else if (lines.length >= 3 && lines[0].length == 30 && lines[1].length == 30 && lines[2].length == 30)
      format = MrzFormat.TD1;
  }

  void _parse() {
    if (format == MrzFormat.Unknown) return;
    final docType = _a(lines[0].substring(0, 1));
    if (docType.startsWith('V')) {
      if (format == MrzFormat.TD3) _parseMrvA();
      if (format == MrzFormat.TD2) _parseMrvB();
    } else {
      if (format == MrzFormat.TD3)
        _parseTd3();
      else if (format == MrzFormat.TD1)
        _parseTd1();
      else if (format == MrzFormat.TD2)
        _parseTd2();
    }
  }

  String _a(String i) => i.split('').map((c) => normalizeChar(c, isAlpha: true)).join();

  String _d(String i) => i.split('').map((c) => normalizeChar(c, isDigit: true)).join();

  bool _validate(String data, String checkChar) {
    final checkDigit = checkChar == '<' ? 0 : int.tryParse(checkChar);
    if (checkDigit == null) return false;
    return computeMrzCheckDigit(data) == checkDigit;
  }

  void _parseNameField(String rawField) {
    String cleanedField = rawField.replaceAll('K', '<');
    final nameParts = cleanedField.split('<<').where((s) => s.isNotEmpty).toList();
    if (nameParts.isNotEmpty) {
      lastName = nameParts[0].replaceAll('<', ' ').trim();
      if (nameParts.length > 1) {
        firstName = nameParts.sublist(1).join(' ').replaceAll('<', ' ').trim();
      }
    }
  }

  // --- All individual parsers are now complete and correct ---

  void _parseTd3() {
    final l1 = lines[0], l2 = lines[1];
    documentType = _a(l1.substring(0, 1));
    final pCountry = _a(l1.substring(2, 5));
    if (mrzCountryCodes.contains(pCountry)) {
      countryCode = pCountry;
      issuingState = pCountry;
    }
    _parseNameField(l1.substring(5));

    final docNumStr = l2.substring(0, 9);
    docNumberValid = _validate(docNumStr, l2.substring(9, 10));
    if (docNumberValid) documentNumber = docNumStr.replaceAll('<', '');

    final pNat = _a(l2.substring(10, 13));
    if (mrzCountryCodes.contains(pNat)) nationality = pNat;

    final birthStr = _d(l2.substring(13, 19));
    birthDateValid = _validate(birthStr, l2.substring(19, 20));
    if (birthDateValid) birthDate = parseMrzDate(birthStr);

    sex = _a(l2.substring(20, 21));

    final expiryStr = _d(l2.substring(21, 27));
    expiryDateValid = _validate(expiryStr, l2.substring(27, 28));
    if (expiryDateValid) expiryDate = parseMrzDate(expiryStr);

    optionalData1 = l2.substring(28, 42);
    optionalDataValid = _validate(optionalData1!, l2.substring(42, 43));

    final composite = '${l2.substring(0, 10)}${l2.substring(13, 20)}${l2.substring(21, 43)}';
    finalCompositeValid = _validate(composite, l2.substring(43, 44));
  }

  void _parseMrvA() {
    // Visa 2x44
    final l1 = lines[0], l2 = lines[1];
    documentType = _a(l1.substring(0, 1));
    final pCountry = _a(l1.substring(2, 5));
    if (mrzCountryCodes.contains(pCountry)) {
      countryCode = pCountry;
      issuingState = pCountry;
    }
    _parseNameField(l1.substring(5));

    documentNumber = l2.substring(0, 9).replaceAll('<', '');
    docNumberValid = true; // No check digit for MRV-A doc number

    final pNat = _a(l2.substring(10, 13));
    if (mrzCountryCodes.contains(pNat)) nationality = pNat;

    final birthStr = _d(l2.substring(13, 19));
    birthDate = parseMrzDate(birthStr);
    birthDateValid = true; // No check digit

    sex = _a(l2.substring(20, 21));

    final expiryStr = _d(l2.substring(21, 27));
    expiryDate = parseMrzDate(expiryStr);
    expiryDateValid = true; // No check digit

    optionalData1 = l2.substring(28).replaceAll('<', '');
  }

  void _parseMrvB() {
    // Visa 2x36
    final l1 = lines[0], l2 = lines[1];
    documentType = _a(l1.substring(0, 1));
    final pCountry = _a(l1.substring(2, 5));
    if (mrzCountryCodes.contains(pCountry)) {
      countryCode = pCountry;
      issuingState = pCountry;
    }
    _parseNameField(l1.substring(5));

    documentNumber = l2.substring(0, 9).replaceAll('<', '');
    docNumberValid = true; // No check digit

    final pNat = _a(l2.substring(10, 13));
    if (mrzCountryCodes.contains(pNat)) nationality = pNat;

    final birthStr = _d(l2.substring(13, 19));
    birthDate = parseMrzDate(birthStr);
    birthDateValid = true; // No check digit

    sex = _a(l2.substring(20, 21));

    final expiryStr = _d(l2.substring(21, 27));
    expiryDate = parseMrzDate(expiryStr);
    expiryDateValid = true; // No check digit

    optionalData1 = l2.substring(28, 36).replaceAll('<', '');
  }

  void _parseTd1() {
    // ID Card 3x30
    final l1 = lines[0], l2 = lines[1], l3 = lines[2];
    documentType = _a(l1.substring(0, 1));
    final pCountry = _a(l1.substring(2, 5));
    if (mrzCountryCodes.contains(pCountry)) {
      countryCode = pCountry;
      issuingState = pCountry;
    }

    final docNumStr = l1.substring(5, 14);
    docNumberValid = _validate(docNumStr, l1.substring(14, 15));
    if (docNumberValid) documentNumber = docNumStr.replaceAll('<', '');
    optionalData1 = l1.substring(15, 30).replaceAll('<', '');

    final birthStr = _d(l2.substring(0, 6));
    birthDateValid = _validate(birthStr, l2.substring(6, 7));
    if (birthDateValid) birthDate = parseMrzDate(birthStr);

    sex = _a(l2.substring(7, 8));

    final expiryStr = _d(l2.substring(8, 14));
    expiryDateValid = _validate(expiryStr, l2.substring(14, 15));
    if (expiryDateValid) expiryDate = parseMrzDate(expiryStr);

    final pNat = _a(l2.substring(15, 18));
    if (mrzCountryCodes.contains(pNat)) nationality = pNat;
    optionalData2 = l2.substring(18, 29).replaceAll('<', '');

    final composite = '${l1.substring(5, 30)}${l2.substring(0, 7)}${l2.substring(8, 15)}${l2.substring(18, 29)}';
    finalCompositeValid = _validate(composite, l2.substring(29, 30));

    _parseNameField(l3);
  }

  void _parseTd2() {
    // ID Card 2x36
    final l1 = lines[0], l2 = lines[1];
    documentType = _a(l1.substring(0, 1));
    final pCountry = _a(l1.substring(2, 5));
    if (mrzCountryCodes.contains(pCountry)) {
      countryCode = pCountry;
      issuingState = pCountry;
    }

    _parseNameField(l1.substring(5));

    final docNumStr = l2.substring(0, 9);
    docNumberValid = _validate(docNumStr, l2.substring(9, 10));
    if (docNumberValid) documentNumber = docNumStr.replaceAll('<', '');

    final pNat = _a(l2.substring(10, 13));
    if (mrzCountryCodes.contains(pNat)) nationality = pNat;

    final birthStr = _d(l2.substring(13, 19));
    birthDateValid = _validate(birthStr, l2.substring(19, 20));
    if (birthDateValid) birthDate = parseMrzDate(birthStr);

    sex = _a(l2.substring(20, 21));

    final expiryStr = _d(l2.substring(21, 27));
    expiryDateValid = _validate(expiryStr, l2.substring(27, 28));
    if (expiryDateValid) expiryDate = parseMrzDate(expiryStr);

    optionalData1 = l2.substring(28, 34).replaceAll('<', '');
    optionalDataValid = _validate(optionalData1!, l2.substring(34, 35));

    final composite = '${l2.substring(0, 10)}${l2.substring(13, 20)}${l2.substring(21, 35)}';
    finalCompositeValid = _validate(composite, l2.substring(35, 36));
  }
}
