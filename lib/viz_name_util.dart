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
  final String givenDisplay;
  final VizNameAgreement agreement;
  final bool needsManualNameVerification;

  const VizNameLookupResult({
    required this.surname,
    required this.givenNames,
    required this.givenDisplay,
    required this.agreement,
    required this.needsManualNameVerification,
  });
}

// Normalises any dash/hyphen variant to ASCII hyphen.
String normalizeDashes(String value) =>
    value.replaceAll(RegExp(r'[\u2010-\u2015\u2212\uFE58\uFE63\uFF0D–—]'), '-');

String normalizeNameForComparison(String value) {
  return normalizeDashes(value)
      .toUpperCase()
      .replaceAll(RegExp(r'[\s\-]+'), '')
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

String _vizHaystack(List<String> vizLines) =>
    vizLines.map(normalizeDashes).join('\n').toUpperCase();

bool tokenInVizHaystack(String token, String haystackUpper) {
  final t = token.toUpperCase();
  if (t.isEmpty) return false;
  if (RegExp(r'(?<![A-Z0-9])' + RegExp.escape(t) + r'(?![A-Z0-9])').hasMatch(haystackUpper)) {
    return true;
  }
  // OCR may glue tokens to punctuation without a clean word boundary.
  if (t.length >= 3 && haystackUpper.contains(t)) return true;
  return false;
}

bool allTokensInViz(List<String> tokens, List<String> vizLines) {
  if (tokens.isEmpty) return false;
  final haystack = _vizHaystack(vizLines);
  return tokens.every((t) => tokenInVizHaystack(t, haystack));
}

/// MRZ tokens appear in VIZ in order (separators between tokens may differ: space, hyphen, line break).
bool tokensAppearInOrder(List<String> tokens, List<String> vizLines) {
  if (tokens.isEmpty) return true;
  final haystack = _vizHaystack(vizLines);
  var pos = 0;
  for (final token in tokens) {
    final t = token.toUpperCase();
    final idx = haystack.indexOf(t, pos);
    if (idx < 0) return false;
    pos = idx + t.length;
  }
  return true;
}

String? findContiguousVizSpan(List<String> tokens, List<String> vizLines) {
  if (tokens.isEmpty) return null;

  // Normalise dashes in the VIZ lines so OCR variants don't prevent matching.
  final normalizedLines = vizLines.map(normalizeDashes).toList();

  if (tokens.length == 1) {
    final token = tokens.first.toUpperCase();
    for (final line in normalizedLines) {
      final match = RegExp(r'(?<![A-Z0-9])' + RegExp.escape(token) + r'(?![A-Z0-9])', caseSensitive: false).firstMatch(line);
      if (match != null) {
        // Return the span from the original (non-normalised) line so hyphens are preserved.
        final original = vizLines[normalizedLines.indexOf(line)];
        final m2 = RegExp(r'(?<![A-Z0-9])' + RegExp.escape(token) + r'(?![A-Z0-9])', caseSensitive: false).firstMatch(normalizeDashes(original));
        return m2 != null ? original.substring(m2.start, m2.end) : match.group(0);
      }
    }
    return null;
  }

  // Separator between tokens: any combo of whitespace and/or any dash variant.
  const sep = r'[\s\u2010-\u2015\u2212\uFE58\uFE63\uFF0D\-–—]+';
  final pattern = tokens.map(RegExp.escape).join(sep);
  final regex = RegExp(r'(?<![A-Z0-9])(' + pattern + r')(?![A-Z0-9])', caseSensitive: false);

  String? best;
  for (int i = 0; i < normalizedLines.length; i++) {
    final match = regex.firstMatch(normalizedLines[i]);
    if (match != null) {
      // Pull the capture group from the ORIGINAL (un-normalised) line so the real
      // hyphen character (not the normalised ASCII one) is preserved in the output.
      final original = vizLines[i];
      final origMatch = RegExp(r'(?<![A-Z0-9])(' + pattern + r')(?![A-Z0-9])', caseSensitive: false).firstMatch(normalizeDashes(original));
      final span = (origMatch?.group(1) ?? match.group(1)!).trim();
      // Use original char positions from origMatch to get un-normalised text.
      final realSpan = origMatch != null
          ? original.substring(origMatch.start, origMatch.end).trim()
          : span;
      if (best == null || realSpan.length > best.length) best = realSpan;
    }
  }
  return best;
}

String cleanNameSpan(String span) {
  return normalizeDashes(span).replaceAll(RegExp(r'\s+'), ' ').trim();
}

VizNameAgreement agreementForPart(String mrzPart, List<String> vizLines) {
  return agreementForTokens(nameTokens(mrzPart), vizLines);
}

/// Agreement for one name part (surname or given-name tokens from MRZ).
///
/// Strong when every MRZ token is in the VIZ and either:
/// - a contiguous VIZ span normalizes to the same letters as MRZ, or
/// - tokens appear in order in the VIZ (multi-line / mixed space-hyphen separators).
VizNameAgreement agreementForTokens(List<String> tokens, List<String> vizLines) {
  if (tokens.isEmpty) return VizNameAgreement.strong;
  if (!allTokensInViz(tokens, vizLines)) return VizNameAgreement.none;

  final normalizedMrz = normalizeNameForComparison(mrzGivenJoined(tokens));
  final span = findContiguousVizSpan(tokens, vizLines);

  if (span != null && normalizeNameForComparison(span) == normalizedMrz) {
    return VizNameAgreement.strong;
  }

  // Tokens on separate OCR lines, or span includes label noise — same person if in order.
  if (tokensAppearInOrder(tokens, vizLines)) {
    return VizNameAgreement.strong;
  }

  // Every token found somewhere in VIZ but order unclear.
  if (span != null) return VizNameAgreement.weak;

  return VizNameAgreement.weak;
}

VizNameAgreement combineAgreement(VizNameAgreement a, VizNameAgreement b) {
  if (a == VizNameAgreement.skipped || b == VizNameAgreement.skipped) {
    return a == VizNameAgreement.skipped ? b : a;
  }
  if (a == VizNameAgreement.strong && b == VizNameAgreement.strong) {
    return VizNameAgreement.strong;
  }
  if (a == VizNameAgreement.none && b == VizNameAgreement.none) {
    return VizNameAgreement.none;
  }
  if (a == VizNameAgreement.none || b == VizNameAgreement.none) {
    return VizNameAgreement.weak;
  }
  if (a == VizNameAgreement.weak || b == VizNameAgreement.weak) {
    return VizNameAgreement.weak;
  }
  return VizNameAgreement.weak;
}

List<String> splitGivenNames(String value) {
  return nameTokens(value);
}

/// MRZ token list as a single string for agreement checks only (spaces between parts).
String mrzGivenJoined(List<String> givenNames) => givenNames.join(' ');

/// Best display form: VIZ contiguous span when found, otherwise MRZ space-separated fallback.
String resolveGivenDisplay(List<String> givenNames, List<String> vizLines) {
  if (givenNames.isEmpty) return '';
  final span = findContiguousVizSpan(givenNames, vizLines);
  if (span != null && span.trim().isNotEmpty) return cleanNameSpan(span);
  return mrzGivenJoined(givenNames);
}

VizNameAgreement agreementForGivenNames(List<String> givenNames, List<String> vizLines) {
  return agreementForTokens(givenNames, vizLines);
}

/// Applies VIZ lookup to an MRZ-parsed name using non-MRZ OCR lines.
VizNameLookupResult applyVizNameLookup({
  required String surname,
  required List<String> givenNames,
  required Iterable<String> ocrLines,
}) {
  final vizLines = filterVizLines(ocrLines);
  final mrzGivenFallback = mrzGivenJoined(givenNames);

  if (vizLines.isEmpty) {
    return VizNameLookupResult(
      surname: surname,
      givenNames: givenNames,
      givenDisplay: mrzGivenFallback,
      agreement: VizNameAgreement.skipped,
      needsManualNameVerification: true,
    );
  }

  final surnameAgreement = agreementForPart(surname, vizLines);
  final givenAgreement = agreementForGivenNames(givenNames, vizLines);
  final agreement = combineAgreement(surnameAgreement, givenAgreement);

  if (agreement == VizNameAgreement.strong) {
    final vizSurname = cleanNameSpan(findContiguousVizSpan(nameTokens(surname), vizLines) ?? surname);
    final vizGivenRaw = givenNames.isEmpty
        ? ''
        : cleanNameSpan(findContiguousVizSpan(givenNames, vizLines) ?? mrzGivenFallback);
    final vizGiven = vizGivenRaw.isEmpty ? givenNames : splitGivenNames(vizGivenRaw);

    return VizNameLookupResult(
      surname: vizSurname,
      givenNames: vizGiven.isEmpty ? givenNames : vizGiven,
      givenDisplay: vizGivenRaw,
      agreement: VizNameAgreement.strong,
      needsManualNameVerification: false,
    );
  }

  final display = resolveGivenDisplay(givenNames, vizLines);

  if (agreement == VizNameAgreement.weak) {
    return VizNameLookupResult(
      surname: surname,
      givenNames: givenNames,
      givenDisplay: display,
      agreement: VizNameAgreement.weak,
      needsManualNameVerification: true,
    );
  }

  return VizNameLookupResult(
    surname: surname,
    givenNames: givenNames,
    givenDisplay: display,
    agreement: VizNameAgreement.none,
    needsManualNameVerification: true,
  );
}
