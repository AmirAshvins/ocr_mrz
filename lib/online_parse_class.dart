import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';
import 'package:ocr_mrz/mrz_result_class_fix.dart';

class ApiResponse {
  final bool success;
  final int errorCode;
  final String message;
  final DocumentScanResponse? response;

  const ApiResponse({required this.success, required this.errorCode, required this.message, this.response});

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(success: json['success'] ?? false, errorCode: json['errorCode'] ?? 0, message: json['message'] ?? '', response: json['response'] != null ? DocumentScanResponse.fromJson(json['response']) : null);
  }

  OcrMrzResult toOcrMrzResult() {
    return OcrMrzResult(
      line1: '',
      line2: '',
      format: '',
      documentCode: response?.type.value??'',
      documentType: "${response?.type.value??''}${ response?.subType.value??''}",
      mrzFormat: '',
      countryCode: '${response?.issueCountry.value??''}',
      issuingState: '${response?.issueCountry.value??''}',
      lastName: '${response?.lastName.value??response?.fullname.value??''}',
      firstName: '${response?.firstName.value??''}',
      documentNumber: '${response?.documentNumber.value??''}',
      nationality: '${response?.nationality.value??''}',
      birthDate: DateTime.tryParse('${response?.birthDate.value??''}'),
      expiryDate: DateTime.tryParse('${response?.expiryDate.value??''}'),
      sex: '${response?.gender.value??''}',
      personalNumber: '',
      optionalData: '',
      valid: OcrMrzValidation(),
      checkDigits: CheckDigits(document: false, birth: false, expiry: false, optional: false),
      ocrData: OcrData(text: "", lines: []),
      bDataCheck: response?.birthDate.checkDigit,
      eDataCheck: response?.expiryDate.checkDigit,
      numberCheck: response?.documentNumber.checkDigit,
      birthStr: response?.birthDate.value,
      expStr: response?.expiryDate.value
    );
  }
}

class ConfidenceField {
  final String? value;
  final String? checkDigit;
  final int percent;

  const ConfidenceField({this.value, required this.percent,this.checkDigit});

  factory ConfidenceField.fromJson(Map<String, dynamic> json) {
    return ConfidenceField(value: json['value']?.toString(), percent: json['percent'] ?? 0,checkDigit: json["checkDigit"]);
  }
}

class DocumentScanResponse {
  final String id;

  final ConfidenceField type;
  final ConfidenceField subType;
  final ConfidenceField documentNumber;
  final ConfidenceField firstName;
  final ConfidenceField lastName;
  final ConfidenceField birthDate;
  final ConfidenceField expiryDate;
  final ConfidenceField gender;
  final ConfidenceField nationality;
  final ConfidenceField issueCountry;
  final ConfidenceField fullname;

  const DocumentScanResponse({
    required this.id,
    required this.type,
    required this.subType,
    required this.documentNumber,
    required this.birthDate,
    required this.firstName,
    required this.lastName,
    required this.expiryDate,
    required this.gender,
    required this.nationality,
    required this.issueCountry,
    required this.fullname,
  });

  factory DocumentScanResponse.fromJson(Map<String, dynamic> json) {
    ConfidenceField parse(String key) {
      return ConfidenceField.fromJson((json[key] as Map<String, dynamic>?) ?? const {});
    }

    return DocumentScanResponse(
      id: json['id'] ?? '',
      type: parse('type'),
      subType: parse('subType'),
      lastName: parse('lastName'),
      firstName: parse('firstName'),
      documentNumber: parse('documentNumber'),
      birthDate: parse('birthDate'),
      expiryDate: parse('expiryDate'),
      gender: parse('gender'),
      nationality: parse('nationality'),
      issueCountry: parse('issueCountry'),
      fullname: parse('name'),
    );
  }
}
