class MrzLineFixer {
  static const int _td3Total = 44;
  static const int _nameWidth = 39;

  static String fixTd3Line1(String line1) {
    if (line1.isEmpty) return line1;
    final up = line1.toUpperCase();
    final padded = up.length >= _td3Total ? up.substring(0, _td3Total) : up.padRight(_td3Total, '<');

    final docCode = padded.substring(0, 2); // e.g. "P<"
    final issuer = padded.substring(2, 5); // e.g. "CAN"
    final nameRaw = padded.substring(5); // cols 6–44 (39 chars)

    final fixedName = _fixNameField(nameRaw, width: _nameWidth);
    return '$docCode$issuer$fixedName';
  }

  static String _fixNameField(String raw, {required int width}) {
    final matches = RegExp(r'[A-Za-z]+').allMatches(raw).toList();
    if (matches.isEmpty) return ''.padRight(width, '<');

    // collect tokens and the raw substrings between them
    final rawTokens = <String>[];
    final boundaries = <String>[];
    for (var i = 0; i < matches.length; i++) {
      final m = matches[i];
      rawTokens.add(raw.substring(m.start, m.end));
      final nextStart = (i + 1 < matches.length) ? matches[i + 1].start : null;
      if (nextStart != null) {
        boundaries.add(raw.substring(m.end, nextStart));
      }
    }

    String cleanInside(String t) {
      t = t.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
      t = t.replaceAllMapped(RegExp(r'(.)\1{2,}'), (m) => '${m.group(1)}${m.group(1)}'); // keep legit doubles
      return t;
    }

    final baseTokens = rawTokens.map(cleanInside).toList();
    final cleaned = <String>[];

    for (var i = 0; i < baseTokens.length; i++) {
      var t = baseTokens[i];

      // If next boundary contains non-letters, treat trailing C/K as fake '<'
      final boundaryNonLetter = (i < boundaries.length) && RegExp(r'[^A-Za-z]').hasMatch(boundaries[i]);
      if (boundaryNonLetter) {
        final trimmed = t.replaceFirst(RegExp(r'[CK]+$'), '');
        t = trimmed.isNotEmpty ? trimmed : t;
      }

      cleaned.add(t);
    }

    // Enforce minimum length = 3 for every token
    final valid = cleaned.where((s) => s.length >= 3).toList();
    if (valid.isEmpty) return ''.padRight(width, '<');

    final surname = valid.first;
    final given = valid.skip(1).toList();

    var mrz = '$surname<<${given.join('<')}';
    if (mrz.length > width) mrz = mrz.substring(0, width);
    if (mrz.length < width) mrz = mrz.padRight(width, '<');
    return mrz;
  }
}
