import 'const_data_json.dart';

class ConstData {
  final List<OcrMrzDocumentType> documentType;
  final List<OcrMrzDocumentDetailType> documentDetailType;
  final List<OcrMrzDocumentCode> documentCode;
  final List<DocumentAirport> city;
  final List<DocumentCountry> country;
  final List<DocumentAirport> airport;

  ConstData({required this.documentType, required this.documentDetailType, required this.documentCode, required this.city, required this.country, required this.airport});

  ConstData copyWith({
    List<OcrMrzDocumentType>? documentType,
    List<OcrMrzDocumentDetailType>? documentDetailType,
    List<OcrMrzDocumentCode>? documentCode,
    List<DocumentAirport>? city,
    List<DocumentCountry>? country,
    List<DocumentAirport>? airport,
  }) => ConstData(
    documentType: documentType ?? this.documentType,
    documentDetailType: documentDetailType ?? this.documentDetailType,
    documentCode: documentCode ?? this.documentCode,
    city: city ?? this.city,
    country: country ?? this.country,
    airport: airport ?? this.airport,
  );

  factory ConstData.fromJson(Map<String, dynamic> json) => ConstData(
    documentType: List<OcrMrzDocumentType>.from((json["documentType"] ?? []).map((x) => OcrMrzDocumentType.fromJson(x))),
    documentDetailType: List<OcrMrzDocumentDetailType>.from(json["documentDetailType"].map((x) => OcrMrzDocumentDetailType.fromJson(x))),
    documentCode: List<OcrMrzDocumentCode>.from(json["documentCode"].map((x) => OcrMrzDocumentCode.fromJson(x))),
    city: List<DocumentAirport>.from(json["city"].map((x) => DocumentAirport.fromJson(x))),
    country: List<DocumentCountry>.from(json["country"].map((x) => DocumentCountry.fromJson(x))),
    airport: List<DocumentAirport>.from(json["airport"].map((x) => DocumentAirport.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "documentType": List<dynamic>.from(documentType.map((x) => x.toJson())),
    "documentDetailType": List<dynamic>.from(documentDetailType.map((x) => x.toJson())),
    "documentCode": List<dynamic>.from(documentCode.map((x) => x.toJson())),
    "city": List<dynamic>.from(city.map((x) => x.toJson())),
    "country": List<dynamic>.from(country.map((x) => x.toJson())),
    "airport": List<dynamic>.from(airport.map((x) => x.toJson())),
  };

  factory ConstData.offline() => ConstData.fromJson(constDataJson);

  DocumentCountry? getLocationWithCode(String code) {
    if (country.any((a) => a.code3 == code)) {
      return country.firstWhere((a) => a.code3 == code);
    } else {
      return null;
    }
  }
}

class DocumentAirport {
  final String type;
  final String code3;
  final String name;
  final String? country;

  DocumentAirport({required this.type, required this.code3, required this.name, required this.country});

  DocumentAirport copyWith({String? type, String? code3, String? name, String? country}) =>
      DocumentAirport(type: type ?? this.type, code3: code3 ?? this.code3, name: name ?? this.name, country: country ?? this.country);

  factory DocumentAirport.fromJson(Map<String, dynamic> json) => DocumentAirport(type: json["type"], code3: json["code3"], name: json["name"], country: json["country"]);

  Map<String, dynamic> toJson() => {"type": type, "code3": code3, "name": name, "country": country};

  @override
  String toString() => "$code3";
}

class DocumentCountry {
  final String type;
  final String code2;
  final String code3;
  final String name;

  DocumentCountry({required this.type, required this.code2, required this.code3, required this.name});

  DocumentCountry copyWith({String? type, String? code2, String? code3, String? name}) =>
      DocumentCountry(type: type ?? this.type, code2: code2 ?? this.code2, code3: code3 ?? this.code3, name: name ?? this.name);

  factory DocumentCountry.fromJson(Map<String, dynamic> json) => DocumentCountry(type: json["type"], code2: json["code2"], code3: json["code3"] ?? '', name: json["name"]);

  Map<String, dynamic> toJson() => {"type": type, "code2": code2, "code3": code3, "name": name};

  @override
  String toString() => "$code3";
}

class OcrMrzDocumentCode {
  final String name;
  final String code;
  final String type;

  OcrMrzDocumentCode({required this.name, required this.code, required this.type});

  OcrMrzDocumentCode copyWith({String? name, String? code, String? type}) => OcrMrzDocumentCode(name: name ?? this.name, code: code ?? this.code, type: type ?? this.type);

  factory OcrMrzDocumentCode.fromJson(Map<String, dynamic> json) => OcrMrzDocumentCode(name: json["name"], code: json["code"], type: json["type"]);

  Map<String, dynamic> toJson() => {"name": name, "code": code, "type": type};

  @override
  String toString() => "$name";
}

class OcrMrzDocumentDetailType {
  final String type;
  final String subType;
  final String country;
  final String title;
  final String code;
  final String? note;

  OcrMrzDocumentDetailType({required this.type, required this.subType, required this.country, required this.title, required this.code, this.note});

  OcrMrzDocumentDetailType copyWith({String? type, String? subType, String? country, String? title, String? code, String? note}) => OcrMrzDocumentDetailType(
    type: type ?? this.type,
    subType: subType ?? this.subType,
    country: country ?? this.country,
    title: title ?? this.title,
    code: code ?? this.code,
    note: note ?? this.note,
  );

  factory OcrMrzDocumentDetailType.fromJson(Map<String, dynamic> json) =>
      OcrMrzDocumentDetailType(type: json["type"], subType: json["subType"], country: json["country"], title: json["title"], code: json["code"], note: json["note"]);

  Map<String, dynamic> toJson() => {"type": type, "subType": subType, "country": country, "title": title, "code": code, "note": note};
}

class OcrMrzDocumentType {
  final String type;
  final String color;
  final String title;
  final String code;

  OcrMrzDocumentType({required this.type, required this.color, required this.title, required this.code});

  OcrMrzDocumentType copyWith({String? type, String? color, String? title, String? code}) =>
      OcrMrzDocumentType(type: type ?? this.type, color: color ?? this.color, title: title ?? this.title, code: code ?? this.code);

  factory OcrMrzDocumentType.fromJson(Map<String, dynamic> json) => OcrMrzDocumentType(type: json["type"], color: json["color"], title: json["title"], code: json["code"]);

  Map<String, dynamic> toJson() => {"type": type, "color": color, "title": title, "code": code};
}
