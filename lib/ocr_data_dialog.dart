import 'package:camera_kit_plus/camera_kit_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OcrDataDialog extends StatelessWidget {
  final OcrData ocrData;

  final double width;

  final double height;

  const OcrDataDialog({super.key, required this.ocrData, this.width = 350, this.height = 220});

  String _formatDate(DateTime? date) => date == null ? '' : DateFormat('yyyy-MM-dd').format(date);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.blueGrey.shade900, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black45)]),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: []),
      ),
    );
  }
}
