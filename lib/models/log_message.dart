enum LogType { info, success, error, warning }

class LogMessage {
  final String message;
  final LogType type;
  final DateTime timestamp;

  LogMessage({
    required this.message,
    required this.type,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
} 