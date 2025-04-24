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
      onBleConnectionFailed: _showBleConnectionError,
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
    if (_controller.scanningState == ScanningState.nfcScanning || 
        _controller.scanningState == ScanningState.bleScanning) {
      return NfcScannerWidget(controller: _controller);
    } else {
      return QrScannerWidget(controller: _controller);
    }
  }

  // Show warning for duplicate tag
  void _showDuplicateTagWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This tag has already been scanned'),
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
  
  // Show error message for BLE connection failure
  void _showBleConnectionError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Failed to connect to BLE device. Please try again.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
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
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _getScanModeWidget(),
          ),
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
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ConsoleWidget(controller: _controller),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget to display current scanning mode
  Widget _getScanModeWidget() {
    IconData icon;
    String text;
    Color color;
    
    if (_controller.scanningState == ScanningState.qrScanning) {
      icon = Icons.qr_code;
      text = 'QR Mode';
      color = Colors.blue;
    } else if (_controller.scanningState == ScanningState.nfcScanning) {
      icon = Icons.nfc;
      text = 'NFC Mode';
      color = Colors.green;
    } else if (_controller.scanningState == ScanningState.bleScanning) {
      icon = Icons.bluetooth;
      text = 'BLE Mode';
      color = Colors.purple;
    } else {
      icon = Icons.sensors;
      text = 'Idle';
      color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}