import 'package:ocr_mrz/mrz_result_class_fix.dart';

class OcrMrzLog {
  final OcrMrzValidation validation;
  final String rawText;
  final List<String> rawMrzLines;
  final List<String> fixedMrzLines;
  final Map<String, dynamic> extractedData;
  late DateTime time;

  OcrMrzLog({required this.rawText, required this.rawMrzLines, required this.fixedMrzLines, required this.validation, required this.extractedData}) {
    time = DateTime.now();
  }

  Map<String, dynamic> toJson() {
    final extracted = extractedData;
    extracted["ocrData"] = {};
    return {
      'validation': validation.toJson(), // enum name
      'rawText': rawText,
      'rawMrzLines': rawMrzLines,
      'fixedMrzLines': fixedMrzLines,
      'extractedData': extracted,
      'time': time.toIso8601String(),
    };
  }

  factory OcrMrzLog.fromJson(Map<String, dynamic> json) {
    final instance = OcrMrzLog(
      rawText: (json['rawText'] as String?) ?? '',
      rawMrzLines: ((json['rawMrzLines'] as List?) ?? const []).map((e) => e.toString()).toList(),
      fixedMrzLines: ((json['fixedMrzLines'] as List?) ?? const []).map((e) => e.toString()).toList(),
      validation: OcrMrzValidation.fromJson(json["validation"]),
      extractedData: Map<String, dynamic>.from((json['extractedData'] as Map?) ?? const {}),
    );

    instance.time = _parseDate(json['time']);
    return instance;
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is int) {
      // Heuristic: treat >= 1e12 as ms, otherwise seconds.
      return v >= 1000000000000 ? DateTime.fromMillisecondsSinceEpoch(v) : DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }
    if (v is String && v.isNotEmpty) {
      final iso = DateTime.tryParse(v);
      if (iso != null) return iso;
      final asInt = int.tryParse(v);
      if (asInt != null) {
        return asInt >= 1000000000000 ? DateTime.fromMillisecondsSinceEpoch(asInt) : DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
      }
    }
    return DateTime.now();
  }
}
