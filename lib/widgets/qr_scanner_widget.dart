import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../controllers/scanner_controller.dart';
import '../models/scanning_state.dart';

class QrScannerWidget extends StatelessWidget {
  final ScannerController controller;

  const QrScannerWidget({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'QR Code Scanner',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        // QR Scanner Window
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 350,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix([
                controller.contrast, 0, 0, 0, controller.brightness * 128 - 128,
                0, controller.contrast, 0, 0, controller.brightness * 128 - 128,
                0, 0, controller.contrast, 0, controller.brightness * 128 - 128,
                0, 0, 0, 1, 0,
              ]),
              child: controller.scanningState == ScanningState.qrScanning
                  ? MobileScanner(
                      controller: controller.qrController,
                      onDetect: controller.onQrSuccess,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: Text('QR Scanner Inactive'),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Scan a QR code from report.hyperlab.life',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        // Controls
        if (controller.hasFlash && controller.scanningState == ScanningState.qrScanning)
          ElevatedButton.icon(
            onPressed: controller.toggleFlash,
            icon: Icon(controller.isFlashOn ? Icons.flash_off : Icons.flash_on),
            label: Text(controller.isFlashOn ? 'Turn Off Flash' : 'Turn On Flash'),
          ),
      ],
    );
  }
} 