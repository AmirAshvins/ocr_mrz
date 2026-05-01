import 'my_ocr_handler.dart';

class IssueDateGuess {
  final String yymmdd; // raw YYMMDD found
  final DateTime fullDate; // expanded to yyyy-mm-dd (heuristic)
  final String source; // where we found it (segment info)
  final double confidence; // 0..1
  IssueDateGuess(this.yymmdd, this.fullDate, this.source, this.confidence);
}

int _mrzCheck(String s) {
  const w = [7, 3, 1];
  int sum = 0;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    final v =
        (c >= 48 && c <= 57)
            ? c - 48
            : (c >= 65 && c <= 90)
            ? c - 65 + 10
            : 0;
    sum += v * w[i % 3];
  }
  return sum % 10;
}

DateTime? _safeDate(int y, int m, int d) {
  try {
    return DateTime(y, m, d);
  } catch (_) {
    return null;
  }
}

DateTime? _expandYYMMDD(String yymmdd, {DateTime? birth, DateTime? expiry}) {
  final yy = int.parse(yymmdd.substring(0, 2));
  final mm = int.parse(yymmdd.substring(2, 4));
  final dd = int.parse(yymmdd.substring(4, 6));
  final now = DateTime.now();

  // Two candidates: 19yy and 20yy
  final c1 = _safeDate(1900 + yy, mm, dd);
  final c2 = _safeDate(2000 + yy, mm, dd);

  bool ok(DateTime? dt) {
    if (dt == null) return false;
    if (dt.isAfter(now)) return false;
    if (expiry != null && dt.isAfter(expiry)) return false;
    if (birth != null && dt.isBefore(birth)) return false;
    return true;
  }

  final v1 = ok(c1);
  final v2 = ok(c2);
  if (v1 && !v2) return c1;
  if (!v1 && v2) return c2;
  if (v1 && v2) {
    // Prefer the more recent date (closer to expiry, typical for issue date)
    if (expiry != null) {
      final d1 = expiry.difference(c1!).abs();
      final d2 = expiry.difference(c2!).abs();
      return d2 <= d1 ? c2 : c1;
    }
    return c2; // prefer 20yy when both plausible
  }
  // If none fits strict bounds, relax birth constraint:
  if (c2 != null && c2.isBefore(now) && (expiry == null || c2.isBefore(expiry))) return c2;
  if (c1 != null && c1.isBefore(now) && (expiry == null || c1.isBefore(expiry))) return c1;
  return null;
}

String _norm(String s) => s.toUpperCase().replaceAll(' ', '<').trim();

/// Collect the "optional" segments by type
List<(String segment, String source)> _optionalSegments(DocumentStandardType type, String line1, String line2, {String? line3, bool isVisaMRVB = false}) {
  line1 = _norm(line1);
  line2 = _norm(line2);
  line3 = _norm(line3 ?? '');
  final out = <(String, String)>[];

  if (type == DocumentStandardType.td3) {
    // TD3: line2[28..43) (15 chars)
    if (line2.length >= 43) out.add((line2.substring(28, 43), 'TD3:L2[28..42]'));
  } else if (type == DocumentStandardType.td2) {
    // TD2: if visa MRV-B → line2[28..36) (8 chars), else line2[28..35) (7 chars)
    if (isVisaMRVB) {
      if (line2.length >= 36) out.add((line2.substring(28, 36), 'TD2-Visa:L2[28..35]'));
    } else {
      if (line2.length >= 35) out.add((line2.substring(28, 35), 'TD2:L2[28..34]'));
    }
  } else {
    // TD1: line1[15..30) (15 chars) + line2[18..29) (11 chars)
    if (line1.length >= 30) out.add((line1.substring(15, 30), 'TD1:L1[16..30]'));
    if (line2.length >= 29) out.add((line2.substring(18, 29), 'TD1:L2[19..29]'));
  }
  return out;
}

/// Scan optional segments for a plausible issue date (YYMMDD), avoiding birth/expiry.
/// Boost confidence if a following check digit matches.
IssueDateGuess? guessIssueDate({required DocumentStandardType type, required String line1, required String line2, String? line3, bool isVisaMRVB = false, String? birthYYMMDD, String? expiryYYMMDD}) {
  final birth = (birthYYMMDD != null && RegExp(r'^\d{6}$').hasMatch(birthYYMMDD)) ? _expandYYMMDD(birthYYMMDD) : null;
  final expiry = (expiryYYMMDD != null && RegExp(r'^\d{6}$').hasMatch(expiryYYMMDD)) ? _expandYYMMDD(expiryYYMMDD, birth: birth) : null;

  final segs = _optionalSegments(type, line1, line2, line3: line3, isVisaMRVB: isVisaMRVB);
  if (segs.isEmpty) return null;

  IssueDateGuess? best;
  double bestScore = -1;

  for (final (seg, src) in segs) {
    // find YYMMDD or YYMMDD + check digit
    final re = RegExp(r'(\d{6})(\d)?');
    for (final m in re.allMatches(seg)) {
      final yymmdd = m.group(1)!;
      // skip if equals known birth/expiry
      if (birthYYMMDD == yymmdd || expiryYYMMDD == yymmdd) continue;

      final expanded = _expandYYMMDD(yymmdd, birth: birth, expiry: expiry);
      if (expanded == null) continue;

      // base confidence
      double score = 0.6;

      // if followed by a digit that matches MRZ check of YYMMDD, boost a bit
      final chk = m.group(2);
      if (chk != null && chk == _mrzCheck(yymmdd).toString()) score += 0.2;

      // closeness to expiry (issue is typically within 1–10 years before expiry)
      if (expiry != null) {
        final diffDays = expiry.difference(expanded).inDays;
        if (diffDays >= 0 && diffDays <= 365 * 15) score += 0.1;
      }

      // later (more recent) issue date slightly preferred
      score += expanded.millisecondsSinceEpoch / 1e15; // tiny tiebreaker

      if (score > bestScore) {
        bestScore = score;
        best = IssueDateGuess(yymmdd, expanded, src, score.clamp(0.0, 1.0));
      }
    }
  }
  return best;
}
