import 'dart:async';

enum LogFlushReason {
  /// The log batch was flushed due to the periodic timer.
  interval,

  /// The log batch was flushed manually, e.g., after finding a result.
  success,
}

class SessionLogEntry {
  final DateTime timestamp;
  final String message;
  final int? step;
  final Map<String, dynamic> details;

  SessionLogEntry({required this.timestamp, required this.message, this.step, this.details = const {}});

  @override
  String toString() {
    final detailsString = details.isNotEmpty ? " - Details: $details" : "";
    return "[${timestamp.toIso8601String()}] (Step: ${step ?? 'N/A'}) $message$detailsString";
  }

  Map<String, dynamic> toJson() {
    return {"message": "[${timestamp.toIso8601String()}] (Step: ${step ?? 'N/A'}) $message", "step": step, "description": message, "details": details};
    // final detailsString = details.isNotEmpty ? " - Details: $details" : "";
    // return "[${timestamp.toIso8601String()}] (Step: ${step ?? 'N/A'}) $message$detailsString";
  }
}

class SessionLogger {
  final List<SessionLogEntry> _logs = [];
  final int maxLogSize;
  final void Function(SessionLogEntry entry)? onLog;
  final void Function(List<SessionLogEntry> entries, LogFlushReason reason)? onLogBatch;
  final Duration? logInterval;

  Timer? _timer;
  final List<SessionLogEntry> _logBuffer = [];
  bool _hasNewLogs = false;

  SessionLogger({this.maxLogSize = 500, this.onLog, this.onLogBatch, this.logInterval}) {
    if (onLogBatch != null && logInterval != null) {
      final effectiveInterval = logInterval! > Duration.zero ? logInterval! : Duration.zero;
      _timer = Timer.periodic(effectiveInterval, (_) => flush(reason: LogFlushReason.interval));
    }
  }

  void log({required String message, int? step, Map<String, dynamic> details = const {}}) {
    final entry = SessionLogEntry(timestamp: DateTime.now(), message: message, step: step, details: details);

    print(message);
    if (_logs.length >= maxLogSize) {
      _logs.removeAt(0);
    }
    _logs.add(entry);
    _hasNewLogs = true;

    if (_timer != null) {
      _logBuffer.add(entry);
    } else {
      onLog?.call(entry);
    }
  }

  /// Manually flushes the log buffer, calling [onLogBatch] if it's configured.
  void flush({LogFlushReason reason = LogFlushReason.success}) {
    if (_logBuffer.isNotEmpty && _hasNewLogs) {
      onLogBatch?.call(List.unmodifiable(_logBuffer), reason);
      _logBuffer.clear();
      _hasNewLogs = false;
    }
  }

  void clear() {
    _logs.clear();
    _logBuffer.clear();
    _hasNewLogs = false;
  }

  String getFormattedLogs() {
    return _logs.map((entry) => entry.toString()).join('\n');
  }

  void dispose() {
    _timer?.cancel();
    flush(reason: LogFlushReason.success);
  }
}
