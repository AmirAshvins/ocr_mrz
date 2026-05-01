/// Defines which fields must be successfully parsed to consider an MRZ valid.
class MrzValidationSettings {
  final bool validateDocumentNumber;
  final bool validateBirthDate;
  final bool validateExpiryDate;
  final bool validateNames;
  final bool validateNationality;
  final bool validateCountryCode;
  final bool validateFinalCheckDigit;

  /// By default, all core fields are required, but the final composite check digit is optional.
  const MrzValidationSettings({
    this.validateDocumentNumber = true,
    this.validateBirthDate = true,
    this.validateExpiryDate = true,
    this.validateNames = true,
    this.validateNationality = true,
    this.validateCountryCode = true,
    this.validateFinalCheckDigit = false, // Defaulting to false as requested.
  });
}
