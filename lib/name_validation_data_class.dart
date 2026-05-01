import 'package:ocr_mrz/my_name_handler.dart';

class NameValidationData {
  String lastName;
  String firstName;
  String? middleName;

  NameValidationData({required this.lastName, required this.firstName, this.middleName});

  factory NameValidationData.fromJson(Map<String, dynamic> json) => NameValidationData(lastName: json["lastName"], firstName: json["firstName"], middleName: json["middleName"]);

  Map<String, dynamic> toJson() => {"lastName": lastName, "firstName": firstName, "middleName": middleName};

  String get fullname => "${firstName}${middleName} ${lastName}";

  MrzName toMrzName() =>
      MrzName(rawSurname: lastName, rawGivenNames: firstName.split(" ").toList(), surname: lastName, givenNames: firstName.split(" ").toList(), full: "$lastName $middleName $firstName");
}
