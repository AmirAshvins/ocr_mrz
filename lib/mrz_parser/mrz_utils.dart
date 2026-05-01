/// Corrects common OCR errors for a single character based on context.
String normalizeChar(String char, {bool isDigit = false, bool isAlpha = false}) {
  const toDigitMap = {'O': '0', 'I': '1', 'L': '1', 'S': '5', 'B': '8', 'G': '6', 'Z': '2', 'Q': '0', 'D': '0'};
  const toAlphaMap = {'0': 'O', '1': 'I', '5': 'S', '8': 'B', '6': 'G', '2': 'Z'};
  if (isDigit) return toDigitMap[char] ?? char;
  if (isAlpha) return toAlphaMap[char] ?? char;
  return char;
}

/// Aggressively normalizes a line of OCR text to conform to MRZ standards.
String normalizeLine(String line, int expectedLength) {
  // 1. Remove ALL invalid characters (including spaces) and convert to uppercase.
  // We do NOT globally replace 'K' or 'C' here. That's a contextual name parsing task.
  String cleanedLine = line.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9<]'), '');
  
  // 2. Pad with filler characters to meet the expected length.
  while (cleanedLine.length < expectedLength) {
    cleanedLine += '<';
  }

  // 3. Truncate if the line is too long.
  return cleanedLine.length > expectedLength ? cleanedLine.substring(0, expectedLength) : cleanedLine;
}

int computeMrzCheckDigit(String input) {
  final weights = [7, 3, 1];
  int sum = 0;
  for (int i = 0; i < input.length; i++) {
    final char = input[i];
    int value;
    if (RegExp(r'[0-9]').hasMatch(char)) {
      value = int.parse(char);
    } else if (RegExp(r'[A-Z]').hasMatch(char)) {
      value = char.codeUnitAt(0) - 55;
    } else if (char == '<') {
      value = 0;
    } else {
      value = 0;
    }
    sum += value * weights[i % 3];
  }
  return sum % 10;
}

DateTime? parseMrzDate(String yymmdd) {
  if (!RegExp(r'^\d{6}$').hasMatch(yymmdd)) return null;
  try {
    int year = int.parse(yymmdd.substring(0, 2));
    final month = int.parse(yymmdd.substring(2, 4));
    final day = int.parse(yymmdd.substring(4, 6));
    final currentYear = DateTime.now().year;
    final currentCentury = (currentYear ~/ 100) * 100;
    final currentTwoDigitYear = currentYear % 100;
    if (year > currentTwoDigitYear + 10) { 
      year += currentCentury - 100;
    } else {
      year += currentCentury;
    }
    return DateTime.utc(year, month, day);
  } catch (e) {
    return null;
  }
}
