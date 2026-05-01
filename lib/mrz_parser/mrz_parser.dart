import 'package:camera_kit_plus/camera_kit_ocr_plus_view.dart';
import 'package:ocr_mrz/mrz_parser/mrz_aggregator.dart';
import 'package:ocr_mrz/mrz_parser/mrz_candidate.dart';
import 'package:ocr_mrz/mrz_parser/mrz_result.dart';
import 'package:ocr_mrz/mrz_parser/mrz_utils.dart';
import 'package:ocr_mrz/mrz_parser/mrz_validation_settings.dart';

class MrzParser {
  MrzAggregator _aggregator;
  final int confidence;

  MrzParser({this.confidence = 1}) : _aggregator = MrzAggregator(nameConfidence: confidence);

  void reset() {
    _aggregator = MrzAggregator(nameConfidence: confidence);
  }

  Map<String, dynamic> getProgress(OcrData ocrData) {
    return {
      'ocrText': ocrData.text,
      'summaryString': _aggregator.getSummaryString(),
      'shapedMrz': _aggregator.getShapedMrz(),
      'fieldCounts': _aggregator.getProgress(),
    };
  }

  MrzResult? parse(OcrData ocrData, {MrzValidationSettings settings = const MrzValidationSettings()}) {
    final potentialLines = _findPotentialMrzLines(ocrData.lines.map((e) => e.text).toList());
    if (potentialLines == null) return null;

    final firstCleanedLength = potentialLines.first.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9<]'), '').length;
    int targetLength;
    if ((firstCleanedLength - 44).abs() <= 5) targetLength = 44;
    else if ((firstCleanedLength - 36).abs() <= 5) targetLength = 36;
    else if ((firstCleanedLength - 30).abs() <= 5) targetLength = 30;
    else return null;

    final normalizedLines = potentialLines.map((line) => normalizeLine(line, targetLength)).toList();
    
    final candidate = MrzCandidate(lines: normalizedLines);
    _aggregator.add(candidate);
    
    return _aggregator.buildResult(settings);
  }

  List<String>? _findPotentialMrzLines(List<String> allLines) {
    final linePairs = allLines
        .map((line) => MapEntry(line, line.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9<]'), '')))
        .where((pair) => pair.value.length > 20)
        .toList();

    if (linePairs.length < 2) return null;
    
    for (int i = 0; i <= linePairs.length - 3; i++) {
      final group = linePairs.sublist(i, i + 3);
      final len1 = group[0].value.length; final len2 = group[1].value.length; final len3 = group[2].value.length;
      if ((len1 - len2).abs() <= 3 && (len2 - len3).abs() <= 3 && (len1 - 30).abs() <= 5) {
        return group.map((p) => p.key).toList();
      }
    }
    
    for (int i = 0; i <= linePairs.length - 2; i++) {
      final group = linePairs.sublist(i, i + 2);
      final len1 = group[0].value.length; final len2 = group[1].value.length;
      if ((len1 - len2).abs() <= 3) {
        if ((len1 - 44).abs() <= 5 || (len1 - 36).abs() <= 5) {
          return group.map((p) => p.key).toList();
        }
      }
    }
    return null;
  }
}
