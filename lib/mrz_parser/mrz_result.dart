/// Represents the format of the Machine Readable Zone.
enum MrzFormat {
  TD1, // 3 lines of 30 chars
  TD2, // 2 lines of 36 chars
  TD3, // 2 lines of 44 chars
  Unknown,
}

/// A container for the validation status of each check digit.
class MrzCheckDigitResult {
  final bool documentNumber;
  final bool birthDate;
  final bool expiryDate;
  final bool optionalData;
  final bool finalComposite;

  MrzCheckDigitResult({required this.documentNumber, required this.birthDate, required this.expiryDate, required this.optionalData, required this.finalComposite});
}

/// Holds the final, validated data parsed from an MRZ.
class MrzResult {
  final MrzFormat format;
  final List<String> mrzLines;

  // Document fields
  final String documentType;
  final String countryCode;
  final String issuingState;
  final String documentNumber;

  // Personal details
  final String lastName;
  final String firstName;
  final DateTime birthDate;
  final String sex;
  final DateTime expiryDate;
  final String nationality;

  // Optional/Additional data
  final String? optionalData1;
  final String? optionalData2;

  // Validation results
  final MrzCheckDigitResult checkDigits;

  MrzResult({
    required this.format,
    required this.mrzLines,
    required this.documentType,
    required this.countryCode,
    required this.issuingState,
    required this.documentNumber,
    required this.lastName,
    required this.firstName,
    required this.birthDate,
    required this.sex,
    required this.expiryDate,
    required this.nationality,
    this.optionalData1,
    this.optionalData2,
    required this.checkDigits,
  });

  @override
  String toString() {
    return 'MrzResult(\n'
        '  Format: $format\n'
        '  Document Type: $documentType, Country: $countryCode, Number: $documentNumber\n'
        '  Name: $lastName, $firstName\n'
        '  Birth Date: $birthDate, Sex: $sex, Expiry: $expiryDate\n'
        '  Nationality: $nationality\n'
        '  MRZ Lines: \n${mrzLines.join('\n')}\n'
        ')';
  }
}
