import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/scanner_controller.dart';
import '../models/log_message.dart';

class ConsoleWidget extends StatelessWidget {
  final ScannerController controller;

  const ConsoleWidget({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2B2B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        reverse: true,
        itemCount: controller.logMessages.length,
        itemBuilder: (context, index) {
          final log = controller.logMessages[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '[${DateFormat('HH:mm:ss').format(log.timestamp)}] ${log.message}',
              style: TextStyle(
                fontFamily: 'monospace',
                color: log.type == LogType.error
                    ? Colors.red
                    : log.type == LogType.success
                        ? Colors.green
                        : Colors.blue,
                fontSize: 14,
              ),
            ),
          );
        },
      ),
    );
  }
} 