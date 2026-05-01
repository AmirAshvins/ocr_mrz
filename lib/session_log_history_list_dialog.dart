import 'package:flutter/material.dart';
import 'package:ocr_mrz/session_status_class.dart';

class SessionLogHistoryListDialog extends StatelessWidget {
  final List<SessionStatus> historyList;

  const SessionLogHistoryListDialog({super.key, required this.historyList});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: historyList.length,
              itemBuilder: (c, i) {
                SessionStatus s = historyList[i];
                return ListTile(title: Text("$s"), subtitle: Text(s.logDetails ?? ''));
              },
            ),
          ),
        ],
      ),
    );
  }
}
