enum Gender {
  male,
  female,
  other,
  undisclosedU,
  unspecifiedX;

  @override
  toString() => title.toString();
}

extension GenderDetails on Gender {
  String get title {
    switch (this) {
      case Gender.male:
        return "Male";
      case Gender.female:
        return "Female";
      case (Gender.other):
        return "Other";
      case Gender.undisclosedU:
        return "Undisclosed U";
      case Gender.unspecifiedX:
        return "Unspecified X";
    }
  }

  String get value {
    switch (this) {
      case Gender.male:
        return "M";
      case Gender.female:
        return "F";
      case Gender.other:
        return "O";
      case Gender.undisclosedU:
        return "U";
      case Gender.unspecifiedX:
        return "X";
    }
  }

  static Gender? fromValue(String? v) {
    if (v == null) return null;
    v = v.toUpperCase();
    return Gender.values.firstWhere((e) => e.value == v, orElse: () => throw ArgumentError('Unknown Gender: $v'));
  }

  Gender? genderFromJson(String? v) => v == null ? null : Gender.values.firstWhere((e) => e.value == v.toUpperCase(), orElse: () => throw ArgumentError('Unknown Gender: $v'));

  String? genderToJson(Gender? t) => t?.value;
}
