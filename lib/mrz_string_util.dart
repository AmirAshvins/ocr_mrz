/// Shared MRZ string helpers used by parsers and consensus handlers.

/// Strips ICAO filler characters from a raw 9-char MRZ document-number field.
String stripMrzDocNumber(String raw) => raw.replaceAll('O', '0').replaceAll('<', '').trim();

/// Extracts and cleans the document number from TD1 line 1 (positions 5–13).
String mrzDocNumberFromTd1Line1(String line1) {
  if (line1.length < 14) return '';
  return stripMrzDocNumber(line1.substring(5, 14));
}

/// Confidence ratio for a consensus field (0.0 – 1.0).
double mrzFieldConfidence({required int consensusCount, required Map<dynamic, int> histogram}) {
  if (histogram.isEmpty || consensusCount <= 0) return 0;
  final total = histogram.values.fold<int>(0, (a, b) => a + b);
  if (total <= 0) return 0;
  return consensusCount / total;
}

enum MrzNameConfidence { low, medium, high }

MrzNameConfidence mrzNameConfidenceFromCounts({
  required int firstNameConsensusCount,
  required Map<String, int> firstNameHistogram,
  required int lastNameConsensusCount,
  required Map<String, int> lastNameHistogram,
}) {
  final first = mrzFieldConfidence(consensusCount: firstNameConsensusCount, histogram: firstNameHistogram);
  final last = mrzFieldConfidence(consensusCount: lastNameConsensusCount, histogram: lastNameHistogram);
  final avg = (first + last) / 2;
  if (avg >= 0.75 && firstNameConsensusCount >= 2 && lastNameConsensusCount >= 2) {
    return MrzNameConfidence.high;
  }
  if (avg >= 0.4 || firstNameConsensusCount >= 2 || lastNameConsensusCount >= 2) {
    return MrzNameConfidence.medium;
  }
  return MrzNameConfidence.low;
}
