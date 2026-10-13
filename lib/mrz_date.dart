/// Which MRZ `YYMMDD` field is being expanded to a four-digit year.
enum MrzYymmddField {
  /// Date of birth. A civil day after [parseMrzYymmdd]'s clock is the 1900s.
  birth,

  /// Document expiry. May sit up to ten years ahead of the clock.
  expiry,

  /// Optional-field issue date. Not left in the future.
  issue,
}

/// Parses an MRZ `YYMMDD` into a UTC calendar date.
///
/// Birth and issue years that would fall after [now] roll back a century.
/// In 2026 the expiry window `YY <= currentYear + 10` turned birth years
/// 1927–1936 into 2027–2036. That future birth then rejected a real 2020
/// issue date. Expiry keeps the ten-year lookahead, so `15` stays 2015 and
/// `30` stays 2030.
///
/// [now] is the civil clock used for the century. Tests pass a fixed day.
/// Returns null when [yymmdd] is not six digits or the month and day are
/// not a real calendar day.
DateTime? parseMrzYymmdd(
  String yymmdd, {
  required MrzYymmddField field,
  DateTime? now,
}) {
  if (!RegExp(r'^\d{6}$').hasMatch(yymmdd)) return null;
  final year = int.parse(yymmdd.substring(0, 2));
  final month = int.parse(yymmdd.substring(2, 4));
  final day = int.parse(yymmdd.substring(4, 6));
  final clock = now ?? DateTime.now();
  final fullYear = _mrzFullYear(year, month, day, field: field, clock: clock);
  if (fullYear == null) return null;
  return _strictUtc(fullYear, month, day);
}

/// Century for [yy]. Null when the modern candidate is not a real day.
int? _mrzFullYear(
  int yy,
  int month,
  int day, {
  required MrzYymmddField field,
  required DateTime clock,
}) {
  if (field == MrzYymmddField.expiry) {
    final pivot = clock.year % 100;
    // Issued for at most about ten years, so an expiry inside that window
    // is this century. Birth must not share this window.
    return yy <= pivot + 10 ? 2000 + yy : 1900 + yy;
  }
  final modern = _strictUtc(2000 + yy, month, day);
  if (modern == null) return null;
  // One day of slack so a birth dated today is not pushed back to the 1900s.
  final tomorrow = DateTime.utc(
    clock.year,
    clock.month,
    clock.day,
  ).add(const Duration(days: 1));
  if (modern.isAfter(tomorrow)) return 1900 + yy;
  return 2000 + yy;
}

/// UTC date, or null when [month] and [day] overflow (31 Feb).
DateTime? _strictUtc(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime.utc(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}
