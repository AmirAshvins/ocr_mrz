import 'dart:convert';
import 'dart:developer';

import 'package:ocr_mrz/aggregator.dart';
import 'package:ocr_mrz/mrz_parser/mrz_result.dart';
import 'package:ocr_mrz/my_ocr_handler.dart';
import 'package:ocr_mrz/my_ocr_handler_new.dart';
import 'package:ocr_mrz/name_validation_data_class.dart';
import 'package:ocr_mrz/ocr_mrz_api_config.dart';
import 'package:ocr_mrz/ocr_mrz_new_controller.dart';
import 'package:ocr_mrz/ocr_setting_dialog.dart';
import 'package:flutter/material.dart';
import 'package:ocr_mrz/mrz_result_class_fix.dart';
import 'package:ocr_mrz/ocr_mrz.dart';
import 'package:ocr_mrz/ocr_mrz_settings_class.dart';
import 'package:ocr_mrz/orc_mrz_log_class.dart';
import 'package:ocr_mrz/passport_dialog.dart';
import 'package:ocr_mrz/session_logger.dart';
import 'package:ocr_mrz/session_status_class.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Flutter Demo', theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)), home: const MyHomePage(title: 'Flutter Demo Home Page'));
  }
}

String token =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJfaWQiOiI2OTVjMjQwZWJiMmQ5MzE1YWZkN2EwYzgiLCJ1c2VyIjoidGVzdC1tYWhtb3VkIiwibm9uY2UiOiJmMGI5ZjE3Ny03NWM1LTQ1MmEtOWI5Ni1kMWYwMmI2ZTIxMzUiLCJpYXQiOjE3NzMzMzY2NzUsImV4cCI6MTc3NTQ5NjY3NX0.H7fT2PZbw-BEgZPvn3f2Ors3EVQpzwq2aFAb4zjaNdo";

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  OcrMrzController controller = OcrMrzController(
    sessionLogger: SessionLogger(
      logInterval: Duration(seconds: 1),
      onLog: (l) {
        // log(l.toString());
      },
      onLogBatch: (List<SessionLogEntry> lll, LogFlushReason reason) {
        // final lll = ll.where((a)=>((a.step??0) >0));
        //
        // if(lll.isEmpty){
        //   return;
        // }
        // log("${lll.length} ==> log count");
        try {
          for (var l in lll) {
            final encodeed = jsonEncode(l.toJson());
            if (l.step != 0) {
              // log(encodeed);
            }
          }
        } catch (e) {
          // log("$e");
          // if(e is Error){
          //   log("${e.stackTrace}");
          // }
        }
        // log("${reason.name}");
      },
    ),
    // apiConfig: OcrMrzApiConfig(
    //   url: "https://documentReader.multidcs.com/api/v1/document2",
    //   attachPhoto: false,
    //   photoQuality: 35,
    //   headers: {"content-type": "application/json", "Authorization": "Bearer $token"},
    //   bodyBuilder:
    //       (c) => {
    //         "relatedId": null,
    //         "data": {"rawText": c.map((o) => o.text).toList()},
    //       },
    //   interval: Duration(seconds: 2),
    // ),
  );
  OcrMrzControllerNew controllerNew = OcrMrzControllerNew(
    apiConfig: OcrMrzApiConfig(
      url: "https://documentReader.multidcs.com/api/v1/document2",
      attachPhoto: false,
      photoQuality: 35,
      headers: {"content-type": "application/json", "Authorization": "Bearer $token"},
      bodyBuilder:
          (c) => {
            "relatedId": null,
            "data": {"rawText": c.map((o) => o.text).toList()},
          },
      interval: Duration(seconds: 2),
    ),
  );
  bool scanning = true;
  OcrMrzSetting setting = OcrMrzSetting(
    validateBirthDateValid: true,
    validatePersonalNumberValid: false,

    validateLinesLength: false,
    validateFinalCheckValid: false,
    validateExpiryDateValid: true,
    validateDocNumberValid: false,
    validateNames: true,
    algorithm: ParseAlgorithm.method2,
    nameValidationMode: NameValidationMode.contain,
    rotation: 0,
  );
  int logCount = 0;
  OcrMrzLog? lastLog;
  OcrMrzConsensus? improving;
  List<String> fixed = [];
  List<SessionStatus> sessionList = [];

  showFoundPassport(OcrMrzResult res) {
    scanning = false;
    setState(() {});
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return PassportDialog(result: res);
      },
    ).then((a) {
      scanning = true;
      controller.resetSession();
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    // log(lastLog!.fixedMrzLines.join("\n"));
    // log(lastLog!.rawMrzLines.join("\n"));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: GestureDetector(
          onLongPress: () {
            controller.resetSession();
            controllerNew.resetSession();

            // log("changeApiConfig");
            // controller.changeApiConfig(
            //   OcrMrzApiConfig(
            //     url: "https://documentReader.multidcs.com/api/v1/document",
            //     attachPhoto: false,
            //     photoQuality: 10,
            //     headers: {
            //       "Authorization":
            //           "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJfaWQiOiI2OTVjMjQwZWJiMmQ5MzE1YWZkN2EwYzgiLCJ1c2VyIjoiZmFyaGFuZyIsIm5vbmNlIjoiODMyYTIzNjEtZmU3ZC00YmZmLThlY2QtYTRiMzA4MTVhNGY5IiwiaWF0IjoxNzY3NzAyNDQ5LCJleHAiOjE3Njc3MjQwNDl9.a3KaaIyOSXOpJGtibrjFhXLj31EREknA9Qb-qcdZb8s",
            //     },
            //     bodyBuilder:
            //         (c) => {
            //           "relatedId": null,
            //           "data": {"rawText": c.map((o) => o.text).toList()},
            //         },
            //     interval: Duration(seconds: 2),
            //   ),
            // );
            // controller.apiConfigNotifier.value = OcrMrzApiConfig(
            //   url: controller.apiConfigNotifier.value?.url ?? '',
            //   headers: controller.apiConfigNotifier.value?.headers ?? {},
            //   bodyBuilder: (controller.apiConfigNotifier.value?.bodyBuilder) ?? (a) => {},
            //   attachPhoto: false,
            //   interval: Duration(seconds: 2),
            // );
          },
          onTap: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return SessionLogHistoryListDialog(historyList: controller.getSessionHistory.value);
              },
            );
          },
          child: ValueListenableBuilder<List<SessionStatus>>(
            valueListenable: controller.getSessionHistory,
            builder: (context, value, child) {
              return Text("Passport Reader ${sessionList.length}");
            },
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return OcrSettingDialog(current: setting);
                },
              ).then((a) {
                if (a is OcrMrzSetting) {
                  setting = OcrMrzSetting.fromJson(a.toJson());
                  setState(() {});
                }
              });
              // controller.flashOn();
            },
            icon: Icon(Icons.settings),
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton(onPressed: () async {
      //   final path = await controller.takePicture();
      //   log("path :$path");
      //
      // }),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Stack(
                children: [
                  false
                      ? OcrMrzReaderNew(
                        onFoundMrz: (MrzResult result) {
                          log("we found mrz");

                          log(result.toString());
                        },
                        onProgress: (s) {
                          // List<String> lines = s["shapedMrz"];
                          // log("\n${lines.join("\n")}");
                          // String summary = s["summaryString"];
                          // log("${summary}");
                          // log("${s}");
                        },
                        controller: controllerNew,
                      )
                      : OcrMrzReader(
                        onSessionChange: (List<SessionStatus> sl) {
                          if (sl.length > 1) {
                            sessionList = sl;
                            setState(() {});
                          }
                        },
                        nameValidations: [
                          NameValidationData(lastName: "XXXXXX", firstName: "XXXXXX"),
                          NameValidationData(lastName: "OZOLKALNAS", firstName: "LIENE MARASANA"),
                        ],
                        onConsensusChanged: (a) {
                          // log("onCon changed");
                          improving = a;
                          setState(() {});
                        },
                        controller: controller,
                        showFrame: false,
                        setting: setting,

                        countValidation: OcrMrzCountValidation(
                          // nameValidCount: 5
                        ),
                        onFoundMrz: (a) {
                          log("onFoundMrz ${a.toJson()}");
                          if (scanning) {
                            if (a.matchSetting(setting)) {
                              log("${jsonEncode(a.toDocument()?.toJson())}");

                              // showFoundPassport(a);
                            }
                          }
                        },
                        mrzLogger: (l) {
                          if (l.rawMrzLines.isNotEmpty && l.fixedMrzLines.join().trim().isNotEmpty) {
                            logCount++;
                            lastLog = l;
                            fixed = l.fixedMrzLines;
                            setState(() {});

                            // log("log recieved\n${l.fixedMrzLines.join("\n")}");
                            // log("log setted\n${lastLog!.fixedMrzLines.join("\n")}");
                            // log(jsonEncode(l.toJson()));
                          }
                        },
                      ),
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child:
                        lastLog == null
                            ? SizedBox()
                            : Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              color: Colors.white,
                              child: Column(
                                children: [
                                  Row(children: [Expanded(child: FittedBox(child: Text(lastLog!.rawMrzLines.join("\n"))))]),
                                  Divider(),
                                  Row(children: [Expanded(child: FittedBox(child: Text(fixed.join("\n"))))]),
                                  Divider(),
                                  Row(children: [Expanded(child: FittedBox(child: Text(lastLog!.validation.toString())))]),
                                ],
                              ),
                            ),
                  ),
                  Positioned(top: 24, left: 0, right: 0, child: improving == null ? SizedBox() : ImprovingResultWidget(improving!)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImprovingResultWidget extends StatelessWidget {
  final OcrMrzConsensus improving;

  const ImprovingResultWidget(this.improving, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        spacing: 4,
        children: [
          Row(
            spacing: 4,
            children: [
              SingularValidationWidget(state: improving.birthDateStat, label: 'Birth Date', valid: improving.valid.birthDateValid, value: improving.birthDate?.toString(), count: improving.birthDateStat.consensusCount),
              SingularValidationWidget(
                state: improving.expiryDateStat,
                label: 'Expiry Date',
                valid: improving.valid.expiryDateValid ?? false,
                value: improving.expiryDate?.toString(),
                count: improving.expiryDateStat.consensusCount,
              ),
              SingularValidationWidget(state: improving.sexStat, label: 'Gender', valid: improving.valid.expiryDateValid ?? false, value: improving.sex ?? '', count: improving.sexStat.consensusCount),
            ],
          ),
          Row(
            spacing: 4,
            children: [
              SingularValidationWidget(state: improving.nationalityStat, label: 'Nationality', valid: improving.valid.nationalityValid ?? false, value: improving.nationality, count: improving.nationalityStat.consensusCount),
            ],
          ),
          Row(
            spacing: 4,
            children: [
              SingularValidationWidget(state: improving.documentNumberStat, label: 'Doc NO.', valid: improving.valid.docNumberValid ?? false, value: improving.documentNumber, count: improving.documentNumberStat.consensusCount),
              SingularValidationWidget(state: improving.docCodeStat, label: 'Doc Type', valid: improving.valid.docCodeValid ?? false, value: improving.docCode, count: improving.docCodeStat.consensusCount),
              SingularValidationWidget(state: improving.countryCodeStat, label: 'Issuing', valid: improving.valid.countryValid ?? false, value: improving.countryCode, count: improving.countryCodeStat.consensusCount),
            ],
          ),
          Row(
            spacing: 4,
            children: [
              SingularValidationWidget(state: improving.firstNameStat, label: 'Firstname.', valid: improving.valid.nameValid ?? false, value: improving.firstName, count: improving.firstNameStat.consensusCount, rowCount: 2),
              SingularValidationWidget(rowCount: 2, state: improving.lastNameStat, label: 'Lastname', valid: improving.valid.nameValid ?? false, value: improving.lastName, count: improving.lastNameStat.consensusCount),
            ],
          ),
          FittedBox(child: Text(improving!.mrzLines.join("\n"))),
          // Wrap(
          //   runSpacing: 4,
          //   direction: Axis.horizontal,
          //   spacing: 12,
          //
          //   children: [
          //
          //
          //
          //     ?setting.validateFinalCheckValid
          //         ? SingularValidationWidget(
          //             state: improving?.firstNameStat,
          //             label: 'Final Check',
          //             valid: improving?.valid.finalCheckValid ?? false,
          //             value: (improving?.valid.finalCheckValid ?? false) ? "Yes" : "No",
          //             count: improving?.firstNameStat.consensusCount,
          //           )
          //         : null,
          //
          //     ?setting.validatePersonalNumberValid
          //         ? SingularValidationWidget(
          //             state: improving?.personalNumberStat,
          //             label: 'Personal NO.',
          //             valid: improving?.valid.personalNumberValid ?? false,
          //             value: improving?.personalNumber,
          //             count: improving?.personalNumberStat.consensusCount,
          //           )
          //         : null,
          //     ?setting.validateLinesLength
          //         ? SingularValidationWidget(
          //             state: improving?.line1Stat,
          //             label: 'Lines Length',
          //             valid: improving?.valid.linesLengthValid ?? false,
          //             value: (improving?.valid.linesLengthValid ?? false) ? "Yes" : "No",
          //             count: improving?.line1Stat.consensusCount,
          //           )
          //         : null,
          //   ],
          // ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class SingularValidationWidget extends StatelessWidget {
  final String label;
  final String? value;
  final bool valid;
  final FieldStat? state;
  final int? count;
  final int rowCount;

  const SingularValidationWidget({super.key, required this.label, required this.value, required this.valid, required this.count, required this.state, this.rowCount = 4});

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    Color color = valid ? Colors.green : Colors.grey;
    return GestureDetector(
      onTap: () {},
      child: Stack(
        children: [
          Container(
            width: (MediaQuery.of(context).size.width - 60) * (1 / rowCount),
            padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(border: Border.all(color: color, width: 1), color: color.withOpacity(.3), borderRadius: BorderRadius.circular(5)),
            alignment: Alignment.center,
            child: Column(
              children: [
                Text(
                  // "${label} (${count??0})",
                  "${label}",
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10, height: 1),
                ),
                Text(value ?? '', style: TextStyle(color: color, fontSize: 11, height: 1), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Positioned(right: 2, bottom: 2, child: Text('${count?.toString() ?? ''}', style: TextStyle(color: Colors.black, fontSize: 9, height: 1, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
