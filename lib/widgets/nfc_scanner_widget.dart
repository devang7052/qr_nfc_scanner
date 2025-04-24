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
        
        // Scanner mode toggle switch
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Scanner Mode:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: controller.nfcScanMode == NfcScanMode.externalBle,
                onChanged: !controller.isNfcButtonPressed
                    ? (value) => controller.toggleNfcScanMode()
                    : null,
                activeColor: Colors.green,
                activeTrackColor: Colors.green.shade100,
                inactiveThumbColor: Colors.blue,
                inactiveTrackColor: Colors.blue.shade100,
              ),
              Text(
                controller.nfcScanMode == NfcScanMode.externalBle
                    ? 'External BLE'
                    : 'Phone NFC',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: controller.nfcScanMode == NfcScanMode.externalBle
                      ? Colors.green
                      : Colors.blue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // BLE Device connection status (only visible in BLE mode)
        if (controller.nfcScanMode == NfcScanMode.externalBle)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: controller.isConnectedToBleDevice
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: controller.isConnectedToBleDevice
                    ? Colors.green.shade300
                    : Colors.red.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  controller.isConnectedToBleDevice
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: controller.isConnectedToBleDevice
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  controller.isConnectedToBleDevice
                      ? 'Connected to: ${controller.connectedBleDeviceName}'
                      : 'Not connected to BLE device',
                  style: TextStyle(
                    color: controller.isConnectedToBleDevice
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                    fontWeight: FontWeight.w400,
                    fontSize: 12
                  ),
                ),
                const Spacer(),
                if (!controller.isNfcButtonPressed)
                  TextButton(
                    onPressed: controller.isConnectedToBleDevice
                        ? controller.disconnectBleDevice
                        : () => controller.showBleDeviceSelection(context),
                    child: Text(
                      controller.isConnectedToBleDevice ? 'Disconnect' : 'Connect',
                      style: TextStyle(
                        color: controller.isConnectedToBleDevice
                            ? Colors.red
                            : Colors.blue,
                      fontSize: 10
                          
                      ),
                    ),
                  ),
              ],
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
                    controller.nfcScanMode == NfcScanMode.externalBle
                        ? Icons.contactless
                        : Icons.nfc,
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
                      ? controller.nfcScanMode == NfcScanMode.externalBle
                          ? 'External RFID scanner active...'
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
        // Show appropriate button based on state and mode
        if (!controller.isNfcButtonPressed) // When no scan is active
          ElevatedButton.icon(
            onPressed: controller.nfcScanMode == NfcScanMode.externalBle && !controller.isConnectedToBleDevice
                ? null  // Disable button if BLE mode but not connected
                : controller.startNfcScan,
            icon: const Icon(Icons.play_arrow),
            label: Text(
              controller.nfcScanMode == NfcScanMode.externalBle
                  ? 'Start RFID Scan'
                  : 'Start NFC Scan'
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              disabledBackgroundColor: Colors.grey,
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