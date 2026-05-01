// String normalizeName(String str) {
//   return str
//       .toUpperCase()
//       .replaceAll('K', '')                 // حذف K
//       .replaceAll(RegExp(r'[^A-Z]'), '');  // فقط حروف انگلیسی
// }
//
// int levenshtein(String a, String b) {
//   final matrix = List.generate(
//     a.length + 1,
//     (_) => List<int>.filled(b.length + 1, 0),
//   );
//
//   for (int i = 0; i <= a.length; i++) {
//     matrix[i][0] = i;
//   }
//
//   for (int j = 0; j <= b.length; j++) {
//     matrix[0][j] = j;
//   }
//
//   for (int i = 1; i <= a.length; i++) {
//     for (int j = 1; j <= b.length; j++) {
//       final cost = a[i - 1] == b[j - 1] ? 0 : 1;
//
//       matrix[i][j] = [
//         matrix[i - 1][j] + 1,
//         matrix[i][j - 1] + 1,
//         matrix[i - 1][j - 1] + cost
//       ].reduce((a, b) => a < b ? a : b);
//     }
//   }
//
//   return matrix[a.length][b.length];
// }
//
// Map<String, dynamic> findMostSimilar(List<String> names, String target) {
//   final normalizedTarget = normalizeName(target);
//
//   String? bestMatch;
//   double bestScore = double.infinity;
//   int? index;
//   for (final name in names) {
//     final normalizedName = normalizeName(name);
//
//     if (normalizedName.isEmpty) continue;
//
//     final score =
//         levenshtein(normalizedName, normalizedTarget) / normalizedName.length;
//
//     if (score < bestScore) {
//       bestScore = score;
//       bestMatch = name;
//       index = names.indexOf(name);
//     }
//   }
//
//   if (bestScore < 0.4 && bestMatch != null) {
//     return {
//       'match': bestMatch,
//       'distance': bestScore,
//       'index':index
//     };
//   }
//
//   return {
//     'match': '',
//     'distance': double.infinity,
//     'index':null
//   };
// }
