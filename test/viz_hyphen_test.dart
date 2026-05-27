import 'package:flutter_test/flutter_test.dart';
import 'package:ocr_mrz/viz_name_util.dart';

void main() {
  group('VIZ hyphen reconstruction', () {
    test('Romanian sample returns strong agreement and hyphenated given name', () {
      final result = applyVizNameLookup(
        surname: 'BERTEA',
        givenNames: ['ELENA', 'RUXANDRA'],
        ocrLines: [
          'ROMANIA / ROMANIA / ROUMANIE',
          'PASAPORT PE ROU 066016395',
          'PASSPORT / PASSPORT',
          '1. Numele/Surname/Nom',
          'BERTEA',
          '2. Prenumele/Given names/Prenom',
          'ELENA-RUXANDRA',
          '3. Cetatenia/Citizenship/Citoyennete',
          'ROMANA',
          '06 MAI/MAY 06',
          'F',
          'BRAILA',
          '09 SEP/SEP 24',
          '09 SEP/SEP 34',
          'PEROUBERTEA<<ELENA<RUXANDRA<<<<<<<<<<<<<<<<<<',
          '0660163956ROU0605069F3409095606050609001986',
        ],
      );

      expect(result.agreement, VizNameAgreement.strong);
      expect(result.givenDisplay, 'ELENA-RUXANDRA');
      expect(result.givenNames, ['ELENA-RUXANDRA']);
      expect(result.surname, 'BERTEA');
      expect(result.needsManualNameVerification, isFalse);
    });

    test('en-dash from OCR is normalized to ASCII hyphen', () {
      final result = applyVizNameLookup(
        surname: 'BERTEA',
        givenNames: ['ELENA', 'RUXANDRA'],
        ocrLines: ['BERTEA', 'ELENA\u2013RUXANDRA'],
      );

      expect(result.agreement, VizNameAgreement.strong);
      expect(result.givenDisplay, 'ELENA-RUXANDRA');
      expect(result.needsManualNameVerification, isFalse);
    });

    test('label and value on same OCR line still match strongly', () {
      final result = applyVizNameLookup(
        surname: 'BERTEA',
        givenNames: ['ELENA', 'RUXANDRA'],
        ocrLines: [
          '1. Numele/Surname/Nom BERTEA',
          '2. Prenumele/Given names ELENA-RUXANDRA',
          'PEROUBERTEA<<ELENA<RUXANDRA<<<<<<<<<<<<<<<<<<',
        ],
      );

      expect(result.agreement, VizNameAgreement.strong);
      expect(result.givenDisplay, 'ELENA-RUXANDRA');
      expect(result.needsManualNameVerification, isFalse);
    });

    test('triple hyphenated given names are preserved', () {
      final result = applyVizNameLookup(
        surname: 'DUPONT',
        givenNames: ['JEAN', 'PIERRE', 'MARIE'],
        ocrLines: ['DUPONT', 'JEAN-PIERRE-MARIE'],
      );

      expect(result.agreement, VizNameAgreement.strong);
      expect(result.givenDisplay, 'JEAN-PIERRE-MARIE');
      expect(result.needsManualNameVerification, isFalse);
    });

    test('mixed hyphen and space separators are preserved', () {
      final result = applyVizNameLookup(
        surname: 'DUPONT',
        givenNames: ['JEAN', 'PIERRE', 'MARIE'],
        ocrLines: ['DUPONT', 'JEAN-PIERRE MARIE'],
      );

      expect(result.agreement, VizNameAgreement.strong);
      expect(result.givenDisplay, 'JEAN-PIERRE MARIE');
      expect(result.needsManualNameVerification, isFalse);
    });

    test('given names on separate OCR lines still agree strongly', () {
      final result = applyVizNameLookup(
        surname: 'BERTEA',
        givenNames: ['ELENA', 'RUXANDRA'],
        ocrLines: [
          'BERTEA',
          'ELENA',
          'RUXANDRA',
        ],
      );

      expect(result.agreement, VizNameAgreement.strong);
      expect(result.needsManualNameVerification, isFalse);
    });

    test('surname only missing from OCR lines does not false-positive weak on given', () {
      final result = applyVizNameLookup(
        surname: 'BERTEA',
        givenNames: ['ELENA', 'RUXANDRA'],
        ocrLines: ['ELENA-RUXANDRA'],
      );

      expect(result.agreement, VizNameAgreement.weak);
      expect(result.needsManualNameVerification, isTrue);
    });

    test('no non-MRZ lines yields skipped not weak', () {
      final result = applyVizNameLookup(
        surname: 'SMITH',
        givenNames: ['JOHN'],
        ocrLines: [
          'P<USASMITH<<JOHN<<<<<<<<<<<<<<<<<<<<<<<<<<<<',
          '1234567890USA9001011M3001019<<<<<<<<<<<<<<04',
        ],
      );

      expect(result.agreement, VizNameAgreement.skipped);
      expect(result.needsManualNameVerification, isTrue);
    });
  });
}
