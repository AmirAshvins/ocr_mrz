import 'package:flutter/foundation.dart';

import 'mrz_result_class_fix.dart';

enum ParseAlgorithm {
  method1,
  method2,
  method3;

  @override
  toString() {
    switch (this) {
      case ParseAlgorithm.method1:
        return "1";
      case ParseAlgorithm.method2:
        return "2";
      case ParseAlgorithm.method3:
        return "3";
    }
  }
}

enum NameValidationMode {
  none,
  contain,
  exact;

  @override
  toString() {
    switch (this) {
      case NameValidationMode.none:
        return "None";
      case NameValidationMode.contain:
        return "Contain";
      case NameValidationMode.exact:
        return "Match";
    }
  }
}

@immutable
class OcrMrzSetting {
  final bool validateDocNumberValid;
  final bool validateBirthDateValid;
  final bool validateExpiryDateValid;
  final bool validatePersonalNumberValid;
  final bool validateFinalCheckValid;
  final bool validateNames;
  final bool validateLinesLength;
  final bool validateCountry;
  final bool validateNationality;
  final bool validationDocumentCode;
  final int rotation; // degrees (0..359)
  final bool macro;
  final ParseAlgorithm algorithm;
  final NameValidationMode nameValidationMode;

  const OcrMrzSetting({
    this.validateDocNumberValid = true,
    this.validateBirthDateValid = true,
    this.validateExpiryDateValid = true,
    this.validationDocumentCode = true,
    this.validatePersonalNumberValid = false,
    this.validateFinalCheckValid = false,
    this.validateNames = true,
    this.validateLinesLength = false,
    this.validateCountry = true,
    this.validateNationality = true,
    this.rotation = 0,
    this.macro = true,
    this.algorithm = ParseAlgorithm.method2,
    this.nameValidationMode = NameValidationMode.none,
  });

  OcrMrzSetting copyWith({
    bool? validateDocNumberValid,
    bool? validateBirthDateValid,
    bool? validationDocumentCode,
    bool? validateExpiryDateValid,
    bool? validatePersonalNumberValid,
    bool? validateFinalCheckValid,
    bool? validateNames,
    bool? validateLinesLength,
    bool? validateCountry,
    bool? validateNationality,
    int? rotation,
    bool? macro,
    ParseAlgorithm? algorithm,
    NameValidationMode? nameValidationMode,
  }) {
    return OcrMrzSetting(
      validateDocNumberValid: validateDocNumberValid ?? this.validateDocNumberValid,
      validateBirthDateValid: validateBirthDateValid ?? this.validateBirthDateValid,
      validationDocumentCode: validationDocumentCode ?? this.validationDocumentCode,
      validateExpiryDateValid: validateExpiryDateValid ?? this.validateExpiryDateValid,
      validatePersonalNumberValid: validatePersonalNumberValid ?? this.validatePersonalNumberValid,
      validateFinalCheckValid: validateFinalCheckValid ?? this.validateFinalCheckValid,
      validateNames: validateNames ?? this.validateNames,
      validateLinesLength: validateLinesLength ?? this.validateLinesLength,
      validateCountry: validateCountry ?? this.validateCountry,
      validateNationality: validateNationality ?? this.validateNationality,
      rotation: (rotation ?? this.rotation) % 360,
      macro: macro ?? this.macro,
      algorithm: algorithm ?? this.algorithm,
      nameValidationMode: nameValidationMode ?? this.nameValidationMode,
    );
  }

  factory OcrMrzSetting.fromJson(Map<String, dynamic> json) {
    final rot = ((json['rotation'] as num?)?.toInt() ?? 0) % 360;
    return OcrMrzSetting(
      validateDocNumberValid: (json['validateDocNumberValid'] as bool?) ?? true,
      validationDocumentCode: (json['validationDocumentCode'] as bool?) ?? true,
      validateBirthDateValid: (json['validateBirthDateValid'] as bool?) ?? true,
      validateExpiryDateValid: (json['validateExpiryDateValid'] as bool?) ?? true,
      validatePersonalNumberValid: (json['validatePersonalNumberValid'] as bool?) ?? true,
      validateFinalCheckValid: (json['validateFinalCheckValid'] as bool?) ?? true,
      validateNames: (json['validateNames'] as bool?) ?? true,
      validateLinesLength: (json['validateLinesLength'] as bool?) ?? true,
      validateCountry: (json['validateCountry'] as bool?) ?? true,
      validateNationality: (json['validateNationality'] as bool?) ?? true,
      rotation: rot,
      macro: (json['macro'] as bool?) ?? false,
      algorithm: ParseAlgorithm.values.firstWhere((a) => a.index == json["algorithm"]),
      nameValidationMode: NameValidationMode.values.firstWhere((a) => a.index == json["nameValidationMode"]),
    );
  }

  Map<String, dynamic> toJson() => {
    "validateDocNumberValid": validateDocNumberValid,
    "validateBirthDateValid": validateBirthDateValid,
    "validationDocumentCode": validationDocumentCode,
    "validateExpiryDateValid": validateExpiryDateValid,
    "validatePersonalNumberValid": validatePersonalNumberValid,
    "validateFinalCheckValid": validateFinalCheckValid,
    "validateNames": validateNames,
    "validateLinesLength": validateLinesLength,
    "validateCountry": validateCountry,
    "validateNationality": validateNationality,
    "rotation": rotation,
    "macro": macro,
    "algorithm": algorithm.index,
    "nameValidationMode": nameValidationMode.index,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OcrMrzSetting &&
          validateDocNumberValid == other.validateDocNumberValid &&
          validateBirthDateValid == other.validateBirthDateValid &&
          validationDocumentCode == other.validationDocumentCode &&
          validateExpiryDateValid == other.validateExpiryDateValid &&
          validatePersonalNumberValid == other.validatePersonalNumberValid &&
          validateFinalCheckValid == other.validateFinalCheckValid &&
          validateNames == other.validateNames &&
          validateLinesLength == other.validateLinesLength &&
          validateCountry == other.validateCountry &&
          validateNationality == other.validateNationality &&
          rotation == other.rotation &&
          algorithm == other.algorithm &&
          nameValidationMode == other.nameValidationMode &&
          macro == other.macro;

  @override
  int get hashCode => Object.hash(
    validateDocNumberValid,
    validationDocumentCode,
    validateBirthDateValid,
    validateExpiryDateValid,
    validatePersonalNumberValid,
    validateFinalCheckValid,
    validateNames,
    validateLinesLength,
    validateCountry,
    validateNationality,
    rotation,
    macro,
    algorithm,
    nameValidationMode,
  );

  @override
  String toString() =>
      'OcrMrzSetting(macro:$macro, rotation:$rotation, doc:$validateDocNumberValid, code:$validationDocumentCode, '
      'birth:$validateBirthDateValid, exp:$validateExpiryDateValid, pn:$validatePersonalNumberValid, '
      'final:$validateFinalCheckValid, names:$validateNames, len:$validateLinesLength, '
      'country:$validateCountry, nat:$validateNationality) alg:${algorithm.name} nameValidationMode:$nameValidationMode';
}

extension MrzValidationExt on OcrMrzResult {
  bool matchSetting(OcrMrzSetting setting) {
    // log(
    //   '''
    //   ${valid.expiryDateValid} == ${setting.validateExpiryDateValid}
    //   ${valid.finalCheckValid} == ${setting.validateFinalCheckValid}
    //   ${valid.linesLengthValid} == ${setting.validateLinesLength}
    //   ${valid.nameValid} == ${setting.validateNames}
    //   ${valid.nationalityValid} == ${setting.validateNationality}
    //   ${valid.personalNumberValid} == ${setting.validatePersonalNumberValid}
    //   ${valid.birthDateValid} == ${setting.validateBirthDateValid}
    //   ${valid.countryValid} == ${setting.validateCountry}
    //   ${valid.docNumberValid} == ${setting.validateDocNumberValid}
    //   '''
    // );

    return (valid.expiryDateValid || !setting.validateExpiryDateValid) &&
        (valid.finalCheckValid || !setting.validateFinalCheckValid) &&
        (valid.linesLengthValid || !setting.validateLinesLength) &&
        (valid.nameValid || !setting.validateNames) &&
        (valid.nationalityValid || !setting.validateNationality) &&
        (valid.personalNumberValid || !setting.validatePersonalNumberValid) &&
        (valid.birthDateValid || !setting.validateBirthDateValid) &&
        (valid.countryValid || !setting.validateCountry) &&
        (valid.docNumberValid || !setting.validateDocNumberValid);
  }
}
