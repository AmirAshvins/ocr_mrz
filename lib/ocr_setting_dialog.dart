import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ocr_mrz/ocr_mrz_settings_class.dart';

class OcrSettingDialog extends StatefulWidget {
  final OcrMrzSetting current;

  const OcrSettingDialog({super.key, required this.current});

  @override
  State<OcrSettingDialog> createState() => _OcrSettingDialogState();
}

class _OcrSettingDialogState extends State<OcrSettingDialog> {
  late OcrMrzSetting tmp = widget.current;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(padding: const EdgeInsets.all(8.0), child: Text("Settings", style: TextStyle(fontWeight: FontWeight.bold))),
          Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: Text("Name")),
                    CupertinoSwitch(
                      value: tmp.validateNames,
                      onChanged: (a) {
                        tmp = tmp.copyWith(validateNames: a);
                        setState(() {});
                      },
                    ),
                  ],
                ),
                // Row(
                //   children: [
                //     Expanded(child: Text("Lines Length")),
                //     CupertinoSwitch(
                //       value: tmp.validateLinesLength,
                //       onChanged: (a) {
                //         tmp = tmp.copyWith(validateLinesLength: a);
                //
                //         setState(() {});
                //       },
                //     ),
                //   ],
                // ),
                Row(
                  children: [
                    Expanded(child: Text("Issuing County")),
                    CupertinoSwitch(
                      value: tmp.validateCountry,
                      onChanged: (a) {
                        tmp = tmp.copyWith(validateCountry: a);

                        setState(() {});
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Text("Nationality")),
                    CupertinoSwitch(
                      value: tmp.validateNationality,
                      onChanged: (a) {
                        tmp = tmp.copyWith(validateNationality: a);

                        setState(() {});
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Text("Document Type")),
                    CupertinoSwitch(
                      value: tmp.validationDocumentCode,
                      onChanged: (a) {
                        tmp = tmp.copyWith(validationDocumentCode: a);
                        setState(() {});
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Text("BirthDate")),
                    CupertinoSwitch(
                      value: tmp.validateBirthDateValid,
                      onChanged: (a) {
                        tmp = tmp.copyWith(validateBirthDateValid: a);

                        setState(() {});
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Text("ExpiryDate")),
                    CupertinoSwitch(
                      value: tmp.validateExpiryDateValid,
                      onChanged: (a) {
                        tmp = tmp.copyWith(validateExpiryDateValid: a);

                        setState(() {});
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Text("Document Number")),
                    CupertinoSwitch(
                      value: tmp.validateDocNumberValid,
                      onChanged: (a) {
                        tmp = tmp.copyWith(validateDocNumberValid: a);

                        setState(() {});
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Text("Personal Number")),
                    CupertinoSwitch(
                      value: tmp.validatePersonalNumberValid,
                      onChanged: (a) {
                        tmp = tmp.copyWith(validatePersonalNumberValid: a);

                        setState(() {});
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Text("Final Check")),
                    CupertinoSwitch(
                      value: tmp.validateFinalCheckValid,
                      onChanged: (a) {
                        tmp = tmp.copyWith(validateFinalCheckValid: a);

                        setState(() {});
                      },
                    ),
                  ],
                ),
                Divider(),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text("Rotation"),
                      Expanded(
                        child: CupertinoSegmentedControl<int>(
                          groupValue: tmp.rotation,
                          children: {
                            0: Row(children: [Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Text("0")), RotatedBox(quarterTurns: 0, child: Icon(Icons.portrait_rounded, size: 15))]),
                            90: Row(children: [Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Text("90")), RotatedBox(quarterTurns: 3, child: Icon(Icons.portrait_rounded, size: 15))]),
                            180: Row(children: [Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Text("180")), RotatedBox(quarterTurns: 2, child: Icon(Icons.portrait_rounded, size: 15))]),
                            270: Row(children: [Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Text("270")), RotatedBox(quarterTurns: 1, child: Icon(Icons.portrait_rounded, size: 15))]),
                          },
                          onValueChanged: (a) {
                            tmp = tmp.copyWith(rotation: a);
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text("Parse Algorithm"),
                      Expanded(
                        child: CupertinoSegmentedControl<ParseAlgorithm>(
                          groupValue: tmp.algorithm,
                          children: Map.fromIterable(
                            ParseAlgorithm.values,
                            key: (a) => a,
                            value: (a) => Row(children: [Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Text("${(a as ParseAlgorithm).toString()}"))]),
                          ),
                          onValueChanged: (a) {
                            tmp = tmp.copyWith(algorithm: a);
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text("Name"),
                      Expanded(
                        child: CupertinoSegmentedControl<NameValidationMode>(
                          groupValue: tmp.nameValidationMode,
                          children: Map.fromIterable(
                            NameValidationMode.values,
                            key: (a) => a,
                            value: (a) => Row(children: [Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Text("${(a as NameValidationMode).toString()}"))]),
                          ),
                          onValueChanged: (a) {
                            tmp = tmp.copyWith(nameValidationMode: a);
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(),
                Row(
                  children: [
                    Expanded(child: Text("Macro Mode")),
                    CupertinoSwitch(
                      value: tmp.macro,
                      onChanged: (a) {
                        tmp = tmp.copyWith(macro: a);

                        setState(() {});
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(),
          Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
                  onPressed: () {
                    Navigator.of(context).pop(tmp);
                  },
                  child: Text("Apply"),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ],
      ),
    );
  }
}
