import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hyperlab_nfc_generator/widgets/ble_device_dialouge.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/scan_data.dart';
import '../models/scanning_state.dart';
import '../models/log_message.dart';
import '../services/nfc_service.dart';
import '../services/ble_service.dart';
import '../services/storage_service.dart';

class ScannerController {
  // Controllers
  final MobileScannerController qrController = MobileScannerController();
  
  // Services
  late NfcService nfcService;
  late BleService bleService;
  late StorageService storageService;
  
  // State variables
  ScanningState scanningState = ScanningState.idle;
  NfcScanMode nfcScanMode = NfcScanMode.internal;
  bool isNfcButtonPressed = false;
  bool isFlashOn = false;
  bool hasFlash = false;
  String lastScannedQR = '';
  String currentNfcData = '';
  String nfcStatus = 'Ready to scan';
  double brightness = 1.0;
  double contrast = 1.0;
  
  // BLE state variables
  bool isConnectedToBleDevice = false;
  String connectedBleDeviceName = '';
  
  // Data variables
  List<ScanData> scannedData = [];
  ScanData? pendingRow;
  List<LogMessage> logMessages = [];
  
  // Listeners
  Function(VoidCallback) stateUpdater;
  
  // UI Callbacks that will be set by the screen
  Function? notifyDuplicateNfcTag;
  Function? notifySuccessfulNfcScan;
  Function(BuildContext)? notifyBleConnectionFailed;
  
  ScannerController({required this.stateUpdater}) {
    // Initialize services
    nfcService = NfcService(
      logCallback: logToConsole,
      onNfcSuccess: _handleNfcSuccess,
    );
    
    bleService = BleService(
      logCallback: logToConsole,
      onRfidSuccess: _handleNfcSuccess,
    );
    
    storageService = StorageService(
      logCallback: logToConsole,
    );
  }
  
  /// Initialize the controller
  Future<void> initialize() async {
    await storageService.requestAllPermissions();
    await nfcService.initialize();
    await bleService.initialize();
    await _checkCameraPermission();
    await _loadSavedData();
    
    // Start QR scanning automatically when app opens
    _startQrScan();
  }
  
  /// Dispose the controller
  void dispose() {
    qrController.dispose();
    if (scanningState == ScanningState.nfcScanning || scanningState == ScanningState.bleScanning) {
      nfcService.stopNfcSession();
      bleService.disconnectDevice();
    }
  }
  
  /// Load saved data from storage
  Future<void> _loadSavedData() async {
    final data = await storageService.loadSavedData();
    stateUpdater(() {
      scannedData = data['scannedData'];
      pendingRow = data['pendingRow'];
    });
  }
  
  /// Save data to storage
  Future<void> _saveData() async {
    await storageService.saveData(scannedData, pendingRow);
  }
  
  /// Check camera permissions and flash availability
  Future<void> _checkCameraPermission() async {
    // Request camera permission
    final cameraStatus = await Permission.camera.request();
    
    if (cameraStatus.isGranted) {
      try {
        // Check flash availability
        await qrController.toggleTorch();
        await qrController.toggleTorch(); // Toggle back to original state
        stateUpdater(() {
          hasFlash = true;
        });
      } catch (e) {
        stateUpdater(() {
          hasFlash = false;
        });
        logToConsole('Flash not available: ${e.toString()}', LogType.info);
      }
    }
  }
  
  /// Start QR scanning
  Future<void> startQrScan() async {
    _startQrScan();
  }
  
  void _startQrScan() async {
    if (scanningState == ScanningState.qrScanning) return;
    
    try {
      await qrController.start();
      stateUpdater(() {
        scanningState = ScanningState.qrScanning;
      });
      logToConsole('QR scanner started', LogType.success);
    } catch (e) {
      logToConsole('Error starting QR scanner: $e', LogType.error);
    }
  }
  
  /// Stop QR scanning
  void _stopQrScan() async {
    if (scanningState != ScanningState.qrScanning) return;
    
    try {
      await qrController.stop();
      logToConsole('QR scanner stopped', LogType.success);
    } catch (e) {
      logToConsole('Error stopping QR scanner: $e', LogType.error);
    }
  }
  
  /// Toggle flash on/off
  Future<void> toggleFlash() async {
    try {
      await qrController.toggleTorch();
      stateUpdater(() {
        isFlashOn = !isFlashOn;
      });
      logToConsole('Flash turned ${isFlashOn ? 'on' : 'off'}', LogType.info);
    } catch (e) {
      logToConsole('Error toggling flash: $e', LogType.error);
    }
  }
  
  /// Toggle between internal NFC and external BLE scanning
  void toggleNfcScanMode() {
    stateUpdater(() {
      nfcScanMode = (nfcScanMode == NfcScanMode.internal) 
          ? NfcScanMode.externalBle 
          : NfcScanMode.internal;
      
      logToConsole(
        'Switched to ${nfcScanMode == NfcScanMode.internal ? 'Internal NFC' : 'External BLE'} mode', 
        LogType.info
      );
    });
  }
  
  /// Show the BLE device selection dialog
  void showBleDeviceSelection(BuildContext context) {
    // Use Future.delayed to ensure we're not in the build phase
    Future.delayed(Duration.zero, () {
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        builder: (dialogContext) => BleDeviceDialog(
          startScan: () => bleService.startScan(),
          onDeviceSelected: (device) => _connectToBleDevice(dialogContext, device),
        ),
      );
    });
  }
  
  /// Connect to a selected BLE device
  Future<void> _connectToBleDevice(BuildContext context, BluetoothDevice device) async {
    stateUpdater(() {
      nfcStatus = 'Connecting to ${device.advName}...';
    });
    
    bool success = await bleService.connectToDevice(device);
    
    if (success) {
      stateUpdater(() {
        isConnectedToBleDevice = true;
        connectedBleDeviceName = device.advName.isNotEmpty ? device.advName : 'Unknown Device';
        nfcStatus = 'Connected to BLE device';
      });
    } else {
      stateUpdater(() {
        isConnectedToBleDevice = false;
        nfcStatus = 'BLE connection failed';
      });
      
      // Notify the UI about connection failure
      notifyBleConnectionFailed?.call(context);
    }
  }
  
  /// Disconnect from the BLE device
  Future<void> disconnectBleDevice() async {
    await bleService.disconnectDevice();
    
    stateUpdater(() {
      isConnectedToBleDevice = false;
      connectedBleDeviceName = '';
      nfcStatus = 'BLE device disconnected';
    });
  }
  
  /// Start NFC scanning
  Future<void> startNfcScan() async {
    if (isNfcButtonPressed) return;
    
    // Use different approach based on selected mode
    if (nfcScanMode == NfcScanMode.internal) {
      // Use internal NFC
      bool success = await nfcService.startNfcSession();
      if (success) {
        stateUpdater(() {
          scanningState = ScanningState.nfcScanning;
          isNfcButtonPressed = true;
          nfcStatus = 'Scanning... (Ready for tag)';
        });
      } else {
        stateUpdater(() {
          nfcStatus = 'Please enable NFC in settings';
        });
      }
    } else {
      // Use external BLE RFID reader
      if (!isConnectedToBleDevice) {
        stateUpdater(() {
          nfcStatus = 'Connect to BLE device first';
        });
        return;
      }
      
      bool success = await bleService.sendRfidScanScript();
      if (success) {
        stateUpdater(() {
          scanningState = ScanningState.bleScanning;
          isNfcButtonPressed = true;
          nfcStatus = 'External RFID scanner active';
        });
      } else {
        stateUpdater(() {
          nfcStatus = 'Failed to start external scanner';
        });
      }
    }
  }
  
  /// Stop NFC scanning
  Future<void> stopNfcScan() async {
    if (scanningState != ScanningState.nfcScanning && scanningState != ScanningState.bleScanning) return;
    
    try {
      if (scanningState == ScanningState.nfcScanning) {
        // Stop the NFC session
        nfcService.stopNfcSession();
      } else if (scanningState == ScanningState.bleScanning) {
        // Stop the BLE scanner
        await bleService.stopLuaCode();
      }
      
      stateUpdater(() {
        scanningState = ScanningState.idle;
        nfcStatus = 'Scanner Stopped';
        isNfcButtonPressed = false;
      });
      
      logToConsole('Scanner stopped', LogType.success);
      
      // Automatically restart QR scanning
      _startQrScan();
    } catch (e) {
      logToConsole('Error stopping scanner: $e', LogType.error);
    }
  }
  
  /// Handle QR code detection
  void onQrSuccess(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    
    final String? decodedText = capture.barcodes.first.rawValue;
    if (decodedText == null) return;
    
    try {
      if (lastScannedQR == decodedText) return;
      
      // Check if the QR code is from the required domain
      if (decodedText.startsWith('https://report.hyperlab.life')) {
        lastScannedQR = decodedText;
        
        _addScanData(qrData: decodedText);
        logToConsole('QR Code scanned: $decodedText', LogType.success);
        
        // Stop QR scanning first
        _stopQrScan();
        
        // IMPORTANT: Set the state variables manually first
        stateUpdater(() {
          scanningState = nfcScanMode == NfcScanMode.internal ? ScanningState.nfcScanning : ScanningState.bleScanning;
          nfcStatus = 'Preparing ${nfcScanMode == NfcScanMode.internal ? "NFC" : "RFID"} scan...';
        });
        
        logToConsole('Switching to ${nfcScanMode == NfcScanMode.internal ? "NFC" : "RFID"} mode', LogType.info);
        
        // Use a short delay to ensure state is updated before starting NFC
        Future.delayed(Duration(milliseconds: 100), () {
          // Then call the exact same method as the button press
          startNfcScan();
        });
      }
    } catch (error) {
      logToConsole('Invalid QR Code format: $error', LogType.error);
    }
  }
  
  /// Handle NFC tag success from internal NFC or external BLE
  void _handleNfcSuccess(String nfcText) {
    if (nfcText.isEmpty) return;
    
    // Check for duplicates
    bool isDuplicate = _checkForDuplicateNfcData(nfcText);
    
    stateUpdater(() {
      if (isDuplicate) {
        nfcStatus = 'Duplicate Tag!';
        logToConsole('Duplicate Tag detected: $nfcText', LogType.error);
        
        // Play error sound or vibrate if possible
        HapticFeedback.heavyImpact();
        
        // Notify about duplicate through callback
        _notifyDuplicateNfcTag();
        
        // Reset NFC button state but stay in NFC scanning mode
        isNfcButtonPressed = false;
      } else {
        nfcStatus = 'Tag Read Successfully!';
        currentNfcData = nfcText;
        logToConsole('Tag read: $nfcText', LogType.success);
        
        // Immediately add the NFC data to the pending QR data
        _addScanData(nfcData: nfcText);
        
        // Notify about successful scan
        _notifySuccessfulNfcScan();
        
        // Update the button state
        isNfcButtonPressed = false;
        
        // Delay for a moment to show the success message before returning to QR mode
        Future.delayed(const Duration(milliseconds: 1000), () {
          stopNfcScan();
        });
      }
    });
  }
  
  /// Check if the NFC data already exists in the scanned data
  bool _checkForDuplicateNfcData(String nfcData) {
    bool isDuplicate = false;
    
    // Check in the main scanned data list
    for (var item in scannedData) {
      if (item.nfcData == nfcData) {
        isDuplicate = true;
        break;
      }
    }
    
    // Also check in the pending row
    if (!isDuplicate && pendingRow != null && pendingRow!.nfcData == nfcData) {
      isDuplicate = true;
    }
    
    return isDuplicate;
  }
  
  /// Helper method to add scan data
  void _addScanData({String qrData = '', String nfcData = ''}) {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    
    // If there's QR data, start a new row
    if (qrData.isNotEmpty) {
      // If there's a pending incomplete row, complete it first
      if (pendingRow != null) {
        stateUpdater(() {
          scannedData.add(pendingRow!);
          pendingRow = ScanData(
            timestamp: timestamp,
            qrData: qrData,
          );
        });
      } else {
        stateUpdater(() {
          pendingRow = ScanData(
            timestamp: timestamp,
            qrData: qrData,
          );
        });
      }
    }
    // If there's NFC data and we have a pending row, add it to that row
    else if (nfcData.isNotEmpty && pendingRow != null) {
      stateUpdater(() {
        scannedData.add(ScanData(
          timestamp: pendingRow!.timestamp,
          qrData: pendingRow!.qrData,
          nfcData: nfcData,
        ));
        pendingRow = null;
      });
    }
    // If there's NFC data but no pending row, create new row
    else if (nfcData.isNotEmpty) {
      stateUpdater(() {
        scannedData.add(ScanData(
          timestamp: timestamp,
          nfcData: nfcData,
          qrData: '',
        ));
      });
    }
    
    logToConsole('Scan data updated', LogType.success);
    
    // Save data after every addition
    _saveData();
  }
  
  /// Delete a row from the scanned data
  void deleteRow(int index) {
    stateUpdater(() {
      // Check if we're deleting from the main list or the pending row
      if (index == -1 && pendingRow != null) {
        // Delete pending row
        pendingRow = null;
        logToConsole('Deleted pending row', LogType.success);
      } else if (index >= 0 && index < scannedData.length) {
        // Get the data for logging
        final deletedData = scannedData[index];
        
        // Delete from the main list
        scannedData.removeAt(index);
        logToConsole('Deleted scan data from ${deletedData.timestamp}', LogType.success);
      }
    });
    
    // Save data after deletion
    _saveData();
  }
  
  /// Download CSV file of scanned data
  Future<void> downloadCsv(BuildContext context) async {
    try {
      await storageService.downloadCsv(scannedData, pendingRow);
      // Success notification will be handled by the storage service
    } catch (e) {
      // Show user-friendly error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save CSV file. Please check app permissions in device settings.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }
  
  /// Reset all data
  Future<void> resetAllData() async {
    stateUpdater(() {
      scannedData.clear();
      pendingRow = null;
      lastScannedQR = '';
      currentNfcData = '';
    });
    
    // Save the empty state
    await _saveData();
    
    // Reset NFC
    await nfcService.initialize();
    
    // Disconnect BLE
    if (isConnectedToBleDevice) {
      await disconnectBleDevice();
    }
    
    // If in NFC mode, go back to QR scanning
    if (scanningState == ScanningState.nfcScanning || scanningState == ScanningState.bleScanning) {
      stopNfcScan();
    } else if (scanningState == ScanningState.idle) {
      _startQrScan();
    }
    
    logToConsole('Application reset - all data cleared', LogType.success);
  }
  
  /// Log message to console
  void logToConsole(String message, LogType type) {
    stateUpdater(() {
      logMessages.insert(0, LogMessage(message: message, type: type));
      if (logMessages.length > 100) {
        logMessages.removeLast();
      }
    });
  }
  
  /// Notify of duplicate NFC tag
  void _notifyDuplicateNfcTag() {
    // Will be called from screen through callback
    notifyDuplicateNfcTag?.call();
  }
  
  /// Notify of successful NFC scan
  void _notifySuccessfulNfcScan() {
    // Will be called from screen through callback
    notifySuccessfulNfcScan?.call();
  }
  
  // Set callbacks for UI notifications
  void setNotificationCallbacks({
    required Function onDuplicateTag,
    required Function onSuccessfulScan,
    Function(BuildContext)? onBleConnectionFailed,
  }) {
    notifyDuplicateNfcTag = onDuplicateTag;
    notifySuccessfulNfcScan = onSuccessfulScan;
    notifyBleConnectionFailed = onBleConnectionFailed;
  }
}