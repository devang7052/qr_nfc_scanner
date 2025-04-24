import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/scan_data.dart';
import '../models/scanning_state.dart';
import '../models/log_message.dart';
import '../services/nfc_service.dart';
import '../services/storage_service.dart';
import '../utils/rfid_utils.dart';

class ScannerController {
  // Controllers
  final MobileScannerController qrController = MobileScannerController();
  final TextEditingController rfidInputController = TextEditingController();
  final FocusNode rfidFocusNode = FocusNode();
  
  // Services
  late NfcService nfcService;
  late StorageService storageService;
  
  // State variables
  ScanningState scanningState = ScanningState.idle;
  bool isNfcButtonPressed = false;
  bool isFlashOn = false;
  bool hasFlash = false;
  String lastScannedQR = '';
  String currentNfcData = '';
  String nfcStatus = 'Ready to scan';
  double brightness = 1.0;
  double contrast = 1.0;
  bool useExternalNfcReader = false;
  
  // Data variables
  List<ScanData> scannedData = [];
  ScanData? pendingRow;
  List<LogMessage> logMessages = [];
  
  // RFID collection variables
  String collectedRfidData = '';
  bool isCollectingRfid = false;
  
  // Listeners
  Function(VoidCallback) stateUpdater;
  
  // UI Callbacks that will be set by the screen
  Function? notifyDuplicateNfcTag;
  Function? notifySuccessfulNfcScan;
  
  ScannerController({required this.stateUpdater}) {
    // Initialize services
    nfcService = NfcService(
      logCallback: logToConsole,
      onNfcSuccess: _handleNfcSuccess,
    );
    
    storageService = StorageService(
      logCallback: logToConsole,
    );
    
    // Add listener for RFID input
    rfidInputController.addListener(_handleRfidInput);
  }
  
  /// Initialize the controller
  Future<void> initialize() async {
    await storageService.requestAllPermissions();
    await nfcService.initialize();
    await _checkCameraPermission();
    await _loadSavedData();
    
    // Start QR scanning automatically when app opens
    _startQrScan();
  }
  
  /// Dispose the controller
  void dispose() {
    rfidInputController.removeListener(_handleRfidInput);
    rfidInputController.dispose();
    rfidFocusNode.dispose();
    qrController.dispose();
    if (scanningState == ScanningState.nfcScanning) {
      nfcService.stopNfcSession();
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
  
  /// Start NFC scanning
  Future<void> startNfcScan() async {
    if (isNfcButtonPressed) return;
    
    try {
      if (useExternalNfcReader) {
        // Reset collection variables
        isCollectingRfid = false;
        collectedRfidData = '';
        
        stateUpdater(() {
          scanningState = ScanningState.nfcScanning;
          isNfcButtonPressed = true;
          nfcStatus = 'Ready for RFID scan';
        });
        
        logToConsole('RFID scanner ready', LogType.success);
        
        // Clear any existing text
        rfidInputController.clear();
        
        // Focus the text field with a slight delay to ensure UI is ready
        Future.delayed(Duration(milliseconds: 100), () {
          if (rfidFocusNode.canRequestFocus) {
            rfidFocusNode.requestFocus();
            logToConsole('Focus requested for RFID input', LogType.info);
          }
        });
        
        // Keep the keyboard visible
        SystemChannels.textInput.invokeMethod('TextInput.show');
      } else {
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
      }
    } catch (e) {
      stateUpdater(() {
        isNfcButtonPressed = false;
        nfcStatus = 'Error starting scan';
      });
      logToConsole('Error starting scanner: $e', LogType.error);
    }
  }
  
  /// Stop NFC scanning
  Future<void> stopNfcScan() async {
    if (scanningState != ScanningState.nfcScanning) return;
    
    try {
      if (!useExternalNfcReader) {
        // Only stop the internal NFC session if using built-in NFC
        nfcService.stopNfcSession();
      } else if (isCollectingRfid && collectedRfidData.isNotEmpty) {
        // Process the fully collected RFID data when stopping the scan
        String finalRfidData = collectedRfidData.trim();
        logToConsole('Processing complete RFID data: $finalRfidData', LogType.success);
        
        // Now process the complete RFID data
        _processCompleteRfidData(finalRfidData);
        
        // Reset collection variables
        isCollectingRfid = false;
        collectedRfidData = '';
      }
      
      stateUpdater(() {
        scanningState = ScanningState.idle;
        nfcStatus = 'Scanner Stopped';
        isNfcButtonPressed = false;
      });
      
      logToConsole('Scanner stopped', LogType.success);
      
      // Clear the input field
      rfidInputController.clear();
      
      // Automatically restart QR scanning
      _startQrScan();
    } catch (e) {
      logToConsole('Error stopping scanner: $e', LogType.error);
    }
  }
  
  /// Toggle NFC reader type between built-in and external
  void toggleNfcReaderType(bool useExternal) {
    stateUpdater(() {
      useExternalNfcReader = useExternal;
      isNfcButtonPressed = false;
      
      if (useExternal) {
        nfcStatus = 'Ready for RFID reader';
      } else {
        nfcStatus = 'Ready to scan';
      }
    });
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
          scanningState = ScanningState.nfcScanning;
          nfcStatus = 'Preparing NFC scan...';
        });
        
        logToConsole('Switching to NFC mode', LogType.info);
        
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
  
  /// Handle accumulated RFID input
  void _handleRfidInput() {
    // Get the text and add it to our collection buffer
    String newInput = rfidInputController.text;
    
    if (newInput.isNotEmpty) {
      // Start collecting mode if we have data
      if (!isCollectingRfid) {
        isCollectingRfid = true;
        collectedRfidData = '';
        logToConsole('Started collecting RFID data...', LogType.info);
      }
      
      // Accumulate the data (remove any previous collection to avoid duplication)
      collectedRfidData = newInput;
      
      // Update the status to show we're collecting
      stateUpdater(() {
        nfcStatus = 'Receiving RFID data... (${collectedRfidData.length} chars)';
      });
    }
  }
  
  /// Process complete RFID data from external reader
  void _processCompleteRfidData(String data) {
    try {
      if (data.isEmpty) {
        logToConsole('No RFID data to process', LogType.error);
        return;
      }
      
      // Log the raw input for debugging
      logToConsole('Raw RFID input from external reader: "$data"', LogType.info);
      
      // Format the NFC data using the new conversion method
      final nfcText = RfidUtils.convertRfidFormat(data);
      
      // Check for duplicates
      bool isDuplicate = _checkForDuplicateNfcData(nfcText);
      
      if (isDuplicate) {
        logToConsole('Duplicate NFC Tag detected: $nfcText', LogType.error);
        
        // Notify about duplicate through callback
        _notifyDuplicateNfcTag();
      } else {
        logToConsole('RFID Tag processed: $nfcText', LogType.success);
        
        // Add the NFC data to our records
        _addScanData(nfcData: nfcText);
        
        // Notify about successful scan through callback
        _notifySuccessfulNfcScan();
      }
    } catch (e) {
      logToConsole('Error processing complete RFID data: $e', LogType.error);
    }
  }
  
  /// Handle NFC tag success from internal NFC
  void _handleNfcSuccess(String nfcText) {
    if (nfcText.isEmpty) return;
    
    // Check for duplicates
    bool isDuplicate = _checkForDuplicateNfcData(nfcText);
    
    stateUpdater(() {
      if (isDuplicate) {
        nfcStatus = 'Duplicate NFC Tag!';
        logToConsole('Duplicate NFC Tag detected: $nfcText', LogType.error);
        
        // Play error sound or vibrate if possible
        HapticFeedback.heavyImpact();
        
        // Notify about duplicate through callback
        _notifyDuplicateNfcTag();
        
        // Reset NFC button state but stay in NFC scanning mode
        isNfcButtonPressed = false;
      } else {
        nfcStatus = 'Tag Read Successfully!';
        currentNfcData = nfcText;
        logToConsole('NFC Tag read: $nfcText', LogType.success);
        
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
    
    // If in NFC mode, go back to QR scanning
    if (scanningState == ScanningState.nfcScanning) {
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
  }) {
    notifyDuplicateNfcTag = onDuplicateTag;
    notifySuccessfulNfcScan = onSuccessfulScan;
  }
} 