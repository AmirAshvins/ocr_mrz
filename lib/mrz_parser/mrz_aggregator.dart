import 'package:collection/collection.dart';
import 'package:ocr_mrz/mrz_parser/mrz_candidate.dart';
import 'package:ocr_mrz/mrz_parser/mrz_result.dart';
import 'package:ocr_mrz/mrz_parser/mrz_validation_settings.dart';

class _MajorityVote<T> {
  final Map<T, int> _counts = {};
  final int minConfidence;
  _MajorityVote(this.minConfidence);

  void add(T? value, {int weight = 1}) { if (value != null) _counts.update(value, (c) => c + weight, ifAbsent: () => weight); }
  void clear() => _counts.clear();
  T? get bestGuess => _counts.isEmpty ? null : _counts.entries.sortedBy<num>((e) => e.value).last.key;
  T? get result {
    if (_counts.isEmpty) return null;
    final topEntry = _counts.entries.sortedBy<num>((e) => e.value).last;
    return topEntry.value >= minConfidence ? topEntry.key : null;
  }
  Map<T, int> getCounts() => Map.unmodifiable(_counts);
}

class MrzAggregator {
  final int _nameConfidence;
  late _MajorityVote<String> _lastNameVote, _firstNameVote;
  late _MajorityVote<MrzFormat> _format;
  late _MajorityVote<String> _docType, _country, _issuing, _docNum, _sex, _nat, _opt1, _opt2, _mrzLines;
  late _MajorityVote<DateTime> _birthDate, _expiryDate;
  DateTime? _confirmedBirthDate;
  int _totalFrames=0, _docNumSuccess=0, _birthDateSuccess=0, _expiryDateSuccess=0, _optSuccess=0, _finalSuccess=0;
  
  MrzAggregator({int nameConfidence = 3}) : _nameConfidence = nameConfidence {
    reset();
  }
  
  void reset() {
    _format = _MajorityVote<MrzFormat>(1);
    _docType = _MajorityVote<String>(1);
    _country = _MajorityVote<String>(1);
    _issuing = _MajorityVote<String>(1);
    _docNum = _MajorityVote<String>(1);
    _birthDate = _MajorityVote<DateTime>(1);
    _sex = _MajorityVote<String>(1);
    _expiryDate = _MajorityVote<DateTime>(1);
    _nat = _MajorityVote<String>(1);
    _lastNameVote = _MajorityVote<String>(_nameConfidence);
    _firstNameVote = _MajorityVote<String>(_nameConfidence);
    _opt1 = _MajorityVote<String>(1);
    _opt2 = _MajorityVote<String>(1);
    _mrzLines = _MajorityVote<String>(1);
    _confirmedBirthDate = null;
    _totalFrames=0; _docNumSuccess=0; _birthDateSuccess=0; _expiryDateSuccess=0; _optSuccess=0; _finalSuccess=0;
  }

  void add(MrzCandidate candidate) {
    if (candidate.format == MrzFormat.Unknown) return;
    if (_confirmedBirthDate != null && candidate.birthDate != null && candidate.birthDateValid && candidate.birthDate != _confirmedBirthDate) {
      reset();
    }
    _totalFrames++;

    final int weight = candidate.docNumberValid && candidate.birthDateValid ? 2 : 1;

    _format.add(candidate.format, weight: weight);
    _docType.add(candidate.documentType, weight: weight);
    _country.add(candidate.countryCode, weight: weight);
    _issuing.add(candidate.issuingState, weight: weight);
    _sex.add(candidate.sex, weight: weight);
    _nat.add(candidate.nationality, weight: weight);
    _lastNameVote.add(candidate.lastName, weight: weight);
    _firstNameVote.add(candidate.firstName, weight: weight);
    _opt1.add(candidate.optionalData1, weight: weight);
    _opt2.add(candidate.optionalData2, weight: weight);
    _mrzLines.add(candidate.lines.join('\n'), weight: weight);
    
    if (candidate.docNumberValid) { _docNum.add(candidate.documentNumber, weight: 2); _docNumSuccess++; } else { _docNum.add(candidate.documentNumber); }
    if (candidate.birthDateValid) { _birthDate.add(candidate.birthDate, weight: 2); _birthDateSuccess++; } else { _birthDate.add(candidate.birthDate); }
    if (candidate.expiryDateValid) { _expiryDate.add(candidate.expiryDate, weight: 2); _expiryDateSuccess++; } else { _expiryDate.add(candidate.expiryDate); }

    if (candidate.optionalDataValid) _optSuccess++;
    if (candidate.finalCompositeValid) _finalSuccess++;
    
    _confirmedBirthDate ??= _birthDate.result;
  }
  
  Map<String, Map<dynamic, int>> getProgress() {
    return {
      'format': _format.getCounts(), 'documentType': _docType.getCounts(), 'countryCode': _country.getCounts(),
      'issuingState': _issuing.getCounts(), 'documentNumber': _docNum.getCounts(), 'birthDate': _birthDate.getCounts(),
      'sex': _sex.getCounts(), 'expiryDate': _expiryDate.getCounts(), 'nationality': _nat.getCounts(),
      'lastName': _lastNameVote.getCounts(), 'firstName': _firstNameVote.getCounts(), 'optionalData1': _opt1.getCounts(),
      'optionalData2': _opt2.getCounts(), 'mrzLines': _mrzLines.getCounts(),
    };
  }

  String getSummaryString() {
    final finalCheckOK = _totalFrames > 0 ? (_finalSuccess / _totalFrames) > 0.5 : false;
    final fields = {
      'DocType': _docType.bestGuess, 'Country': _country.bestGuess, 'DocNum': _docNum.bestGuess,
      'BirthDate': _birthDate.bestGuess, 'Expiry': _expiryDate.bestGuess, 'Sex': _sex.bestGuess,
      'Nat.': _nat.bestGuess, 'L.Name': _lastNameVote.bestGuess, 'F.Name': _firstNameVote.bestGuess,
      'Final Check': finalCheckOK ? '✅' : '❌',
    };
    return fields.entries.map((e) => '${e.key} ${e.value != null ? '✅' : '❌'}').join(' | ');
  }

  List<String> getShapedMrz() {
    final format = _format.bestGuess;
    if (format == null) return [];

    String f(String? value, int length) => (value ?? '').padRight(length, '<');
    String d(DateTime? value) => value != null ? '${(value.year % 100).toString().padLeft(2, '0')}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}' : '<<<<<<';
    
    final lName = _lastNameVote.bestGuess;
    final fName = _firstNameVote.bestGuess;

    if (format == MrzFormat.TD3) {
      final line1 = '${f(_docType.bestGuess, 1)}<${f(_country.bestGuess, 3)}${f(lName, 0)}<<${f(fName, 0)}'.padRight(44, '<');
      final line2 = '${f(_docNum.bestGuess, 9)}<${f(_nat.bestGuess, 3)}${d(_birthDate.bestGuess)}<${f(_sex.bestGuess, 1)}${d(_expiryDate.bestGuess)}${f(_opt1.bestGuess, 14)}<<<<<'.padRight(44, '<');
      return [line1, line2];
    } else if (format == MrzFormat.TD1) {
      final line1 = '${f(_docType.bestGuess, 1)}<${f(_country.bestGuess, 3)}${f(_docNum.bestGuess, 9)}<${f(_opt1.bestGuess, 15)}'.padRight(30, '<');
      final line2 = '${d(_birthDate.bestGuess)}<${f(_sex.bestGuess, 1)}${d(_expiryDate.bestGuess)}<${f(_nat.bestGuess, 3)}<<<<<<<<<<<'.padRight(30, '<');
      final line3 = '${f(lName, 0)}<<${f(fName, 0)}'.padRight(30, '<');
      return [line1, line2, line3];
    } else if (format == MrzFormat.TD2) {
      final line1 = '${f(_docType.bestGuess, 1)}<${f(_country.bestGuess, 3)}${f(lName, 0)}<<${f(fName, 0)}'.padRight(36, '<');
      final line2 = '${f(_docNum.bestGuess, 9)}<${f(_nat.bestGuess, 3)}${d(_birthDate.bestGuess)}<${f(_sex.bestGuess, 1)}${d(_expiryDate.bestGuess)}${f(_opt1.bestGuess, 7)}<'.padRight(36, '<');
      return [line1, line2];
    }
    return [];
  }

  MrzResult? buildResult(MrzValidationSettings settings) {
    final docNum = (_docNumSuccess > 0) ? _docNum.bestGuess : _docNum.result;
    final bDate = (_birthDateSuccess > 0) ? _birthDate.bestGuess : _birthDate.result;
    final eDate = (_expiryDateSuccess > 0) ? _expiryDate.bestGuess : _expiryDate.result;
    
    final lName = _lastNameVote.result;
    final fName = _firstNameVote.result;
    
    final nat = _nat.bestGuess;
    final docType = _docType.bestGuess;
    final country = _country.bestGuess;
    final lines = _mrzLines.bestGuess;
    final format = _format.bestGuess;
    final sex = _sex.bestGuess;

    if (settings.validateDocumentNumber && docNum == null) return null;
    if (settings.validateBirthDate && bDate == null) return null;
    if (settings.validateExpiryDate && eDate == null) return null;
    if (settings.validateNames && (lName == null || fName == null)) return null;
    if (settings.validateNationality && nat == null) return null;
    if (settings.validateCountryCode && country == null) return null;
    if (settings.validateFinalCheckDigit && !(_totalFrames > 0 && (_finalSuccess / _totalFrames) > 0.5)) return null;
    
    if(format==null || docType==null || country==null || docNum==null || lName==null || fName==null || bDate==null || sex==null || eDate==null || nat==null || lines == null) {
      return null;
    }

    return MrzResult(
      format: format, mrzLines: lines.split('\n'), documentType: docType, countryCode: country,
      issuingState: _issuing.bestGuess ?? country, documentNumber: docNum, lastName: lName, firstName: fName,
      birthDate: bDate, sex: sex, expiryDate: eDate, nationality: nat,
      optionalData1: _opt1.bestGuess, optionalData2: _opt2.bestGuess,
      checkDigits: MrzCheckDigitResult(
        documentNumber: _docNumSuccess > 0, birthDate: _birthDateSuccess > 0, expiryDate: _expiryDateSuccess > 0,
        optionalData: _optSuccess > 0, finalComposite: _finalSuccess > 0,
      ),
    );
  }
}
