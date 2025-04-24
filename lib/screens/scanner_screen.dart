// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/scanner_controller.dart';
import '../models/scanning_state.dart';
import '../widgets/qr_scanner_widget.dart';
import '../widgets/nfc_scanner_widget.dart';
import '../widgets/scan_data_table_widget.dart';
import '../widgets/console_widget.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late ScannerController _controller;

  @override
  void initState() {
    super.initState();
    // Initialize controller with setState callback
    _controller = ScannerController(stateUpdater: setState);
    
    // Set up notification callbacks
    _controller.setNotificationCallbacks(
      onDuplicateTag: _showDuplicateTagWarning,
      onSuccessfulScan: _showSuccessfulScanMessage,
    );
    
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildScannerContent() {
    // Show appropriate scanner based on current state
    if (_controller.scanningState == ScanningState.nfcScanning) {
      return NfcScannerWidget(controller: _controller);
    } else {
      return QrScannerWidget(controller: _controller);
    }
  }

  void _showRfidTroubleshootingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('RFID Troubleshooting'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('If your RFID reader is not working:'),
            SizedBox(height: 8),
            Text('1. Make sure your RFID reader is properly connected'),
            Text('2. Try reconnecting the reader'),
            Text('3. Some readers require special configuration'),
            Text('4. Check if the reader works in other apps'),
            SizedBox(height: 16),
            Text('You can also try the visible text field which should receive input when you scan a tag.')
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Show warning for duplicate tag
  void _showDuplicateTagWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This NFC tag has already been scanned'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }
  
  // Show success message for successful scan
  void _showSuccessfulScanMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tag scanned successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR & NFC Scanner Tool'),
        actions: [
          // Add state indicator in app bar
          Text(_controller.scanningState == ScanningState.nfcScanning ? 'NFC Mode' : 'QR Mode'),
          const SizedBox(width: 8),
          // Add a refresh button that clears all data
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Show confirmation dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Reset Application'),
                  content: const Text('This will clear all scanned data and restart the scanning process. Continue?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await _controller.resetAllData();
                        Navigator.pop(context);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Application reset completed')),
                        );
                      },
                      child: const Text('Reset All'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'Reset All Data',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Scanner Content
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildScannerContent(),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Data Table Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ScanDataTableWidget(controller: _controller),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Console Section
              Card(
                child: ConsoleWidget(controller: _controller),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 