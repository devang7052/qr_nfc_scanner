import 'package:flutter/material.dart';
import '../controllers/scanner_controller.dart';
import '../models/scanning_state.dart';

class NfcScannerWidget extends StatelessWidget {
  final ScannerController controller;

  const NfcScannerWidget({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'NFC Scanner',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        
        // Add NFC reader toggle switch
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Device NFC'),
            Switch(
              value: controller.useExternalNfcReader,
              onChanged: controller.toggleNfcReaderType,
            ),
            const Text('RFID Reader'),
          ],
        ),
        
        // Update TextField for better handling RFID input
        if (controller.useExternalNfcReader && controller.isNfcButtonPressed)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: controller.rfidInputController,
              focusNode: controller.rfidFocusNode,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'RFID Input (Collecting data...)',
                hintText: 'RFID data will appear here...',
              ),
            ),
          ),
        
        const SizedBox(height: 16),
        // NFC Scanner Window
        Container(
          height: 350,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 2),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade50,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: controller.isNfcButtonPressed
                  ? [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 4,
                      )
                    ]
                  : [],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    controller.useExternalNfcReader ? Icons.contactless : Icons.nfc,
                    size: 100,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Scanner Status',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      controller.nfcStatus,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    controller.isNfcButtonPressed
                      ? controller.useExternalNfcReader
                        ? 'Use your RFID reader to scan a tag'
                        : 'Hold your device near an NFC tag'
                      : 'Press Start Scan to begin',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Show appropriate button based on state
        if (!controller.isNfcButtonPressed) // When no scan is active
          ElevatedButton.icon(
            onPressed: controller.startNfcScan,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start NFC Scan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          )
        else // When scan is active
          ElevatedButton.icon(
            onPressed: controller.stopNfcScan,
            icon: const Icon(Icons.stop),
            label: const Text('Stop Scan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
      ],
    );
  }
} 