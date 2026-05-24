/// Visual Inspection Zone (VIZ) name lookup — reconstruct display spelling from OCR
/// when MRZ tokens match VIZ text (e.g. hyphens in BOTHWELL-VARGA).

enum VizNameAgreement {
  /// Provided list / validation disabled — VIZ lookup not applied.
  skipped,

  /// MRZ tokens match a contiguous VIZ span; reconstructed name is trusted.
  strong,

  /// Tokens appear in VIZ but no reliable span — agent should verify manually.
  weak,

  /// Tokens not found in VIZ OCR lines.
  none,
}

class VizNameLookupResult {
  final String surname;
  final List<String> givenNames;
  final VizNameAgreement agreement;
  final bool needsManualNameVerification;

  const VizNameLookupResult({
    required this.surname,
    required this.givenNames,
    required this.agreement,
    required this.needsManualNameVerification,
  });
}

String normalizeNameForComparison(String value) {
  return value
      .toUpperCase()
      .replaceAll(RegExp(r'[\s\-–—]+'), '')
      .replaceAll(RegExp(r'[^A-Z]'), '');
}

bool looksLikeMrzLine(String line) {
  final compact = line.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  if (compact.length < 28) return false;
  final mrzChars = RegExp(r'[A-Z0-9<]').allMatches(compact).length;
  if (mrzChars / compact.length < 0.85) return false;
  return compact.contains('<') || compact.contains(RegExp(r'\d{6}'));
}

List<String> filterVizLines(Iterable<String> lines) {
  return lines.map((l) => l.trim()).where((l) => l.isNotEmpty && !looksLikeMrzLine(l)).toList();
}

List<String> nameTokens(String value) {
  return value.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
}

bool allTokensInViz(List<String> tokens, List<String> vizLines) {
  if (tokens.isEmpty) return false;
  final haystack = vizLines.join('\n').toUpperCase();
  return tokens.every((t) => haystack.contains(RegExp(r'(?<![A-Z0-9])${RegExp.escape(t.toUpperCase())}(?![A-Z0-9])')));
}

String? findContiguousVizSpan(List<String> tokens, List<String> vizLines) {
  if (tokens.isEmpty) return null;
  if (tokens.length == 1) {
    final token = tokens.first.toUpperCase();
    for (final line in vizLines) {
      final match = RegExp(r'(?<![A-Z0-9])${RegExp.escape(token)}(?![A-Z0-9])', caseSensitive: false).firstMatch(line);
      if (match != null) return match.group(0);
    }
    return null;
  }

  final pattern = tokens.map(RegExp.escape).join(r'[\s\-–—]+');
  final regex = RegExp(r'(?<![A-Z0-9])(' + pattern + r')(?![A-Z0-9])', caseSensitive: false);

  String? best;
  for (final line in vizLines) {
    final match = regex.firstMatch(line);
    if (match != null) {
      final span = match.group(1)!.trim();
      if (best == null || span.length > best.length) best = span;
    }
  }
  return best;
}

String cleanNameSpan(String span) {
  return span.replaceAll(RegExp(r'\s+'), ' ').trim();
}

VizNameAgreement agreementForPart(String mrzPart, List<String> vizLines) {
  final tokens = nameTokens(mrzPart);
  if (tokens.isEmpty) return VizNameAgreement.none;
  if (!allTokensInViz(tokens, vizLines)) return VizNameAgreement.none;

  final span = findContiguousVizSpan(tokens, vizLines);
  if (span == null) return VizNameAgreement.weak;

  final normalizedMrz = normalizeNameForComparison(mrzPart);
  final normalizedSpan = normalizeNameForComparison(span);
  if (normalizedMrz == normalizedSpan) {
    return VizNameAgreement.strong;
  }
  return VizNameAgreement.weak;
}

VizNameAgreement combineAgreement(VizNameAgreement a, VizNameAgreement b) {
  if (a == VizNameAgreement.none || b == VizNameAgreement.none) {
    if (a == VizNameAgreement.none && b == VizNameAgreement.none) return VizNameAgreement.none;
    return VizNameAgreement.weak;
  }
  if (a == VizNameAgreement.weak || b == VizNameAgreement.weak) return VizNameAgreement.weak;
  if (a == VizNameAgreement.strong && b == VizNameAgreement.strong) return VizNameAgreement.strong;
  return VizNameAgreement.weak;
}

List<String> splitGivenNames(String value) {
  return nameTokens(value);
}

/// Applies VIZ lookup to an MRZ-parsed name using non-MRZ OCR lines.
VizNameLookupResult applyVizNameLookup({
  required String surname,
  required List<String> givenNames,
  required Iterable<String> ocrLines,
}) {
  final vizLines = filterVizLines(ocrLines);
  if (vizLines.isEmpty) {
    return VizNameLookupResult(
      surname: surname,
      givenNames: givenNames,
      agreement: VizNameAgreement.weak,
      needsManualNameVerification: true,
    );
  }

  final givenDisplay = givenNames.isNotEmpty ? givenNames.join(' ') : '';
  final surnameAgreement = agreementForPart(surname, vizLines);
  final givenAgreement = givenDisplay.isEmpty ? VizNameAgreement.strong : agreementForPart(givenDisplay, vizLines);
  final agreement = combineAgreement(surnameAgreement, givenAgreement);

  if (agreement == VizNameAgreement.strong) {
    final vizSurname = cleanNameSpan(findContiguousVizSpan(nameTokens(surname), vizLines) ?? surname);
    final vizGivenRaw = givenDisplay.isEmpty
        ? ''
        : cleanNameSpan(findContiguousVizSpan(nameTokens(givenDisplay), vizLines) ?? givenDisplay);
    final vizGiven = vizGivenRaw.isEmpty ? givenNames : splitGivenNames(vizGivenRaw);

    return VizNameLookupResult(
      surname: vizSurname,
      givenNames: vizGiven.isEmpty ? givenNames : vizGiven,
      agreement: VizNameAgreement.strong,
      needsManualNameVerification: false,
    );
  }

  if (agreement == VizNameAgreement.weak) {
    return VizNameLookupResult(
      surname: surname,
      givenNames: givenNames,
      agreement: VizNameAgreement.weak,
      needsManualNameVerification: true,
    );
  }

  return VizNameLookupResult(
    surname: surname,
    givenNames: givenNames,
    agreement: VizNameAgreement.none,
    needsManualNameVerification: true,
  );
}
