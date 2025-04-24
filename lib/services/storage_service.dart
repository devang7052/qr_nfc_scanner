import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/scan_data.dart';
import '../models/log_message.dart';

class StorageService {
  final Function(String, LogType) logCallback;

  StorageService({required this.logCallback});

  /// Requests all necessary storage permissions
  Future<void> requestAllPermissions() async {
    try {
      // Request storage permissions at startup for both Android versions
      if (Platform.isAndroid) {
        // For Android 10 and below
        await Permission.storage.request();
        
        // For Android 11+, try to get manage external storage permission
        try {
          await Permission.manageExternalStorage.request();
        } catch (e) {
          // Might not be available on all devices
          logCallback('Advanced storage permission not available', LogType.info);
        }
      }
      
      logCallback('Storage permissions requested', LogType.success);
    } catch (e) {
      logCallback('Error requesting permissions: $e', LogType.error);
    }
  }

  /// Loads saved scanned data from local storage
  Future<Map<String, dynamic>> loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedDataString = prefs.getString('scanned_data');
      final String? pendingRowString = prefs.getString('pending_row');
      
      List<ScanData> scannedData = [];
      ScanData? pendingRow;
      
      if (savedDataString != null) {
        final List<dynamic> savedDataList = jsonDecode(savedDataString);
        scannedData = savedDataList.map((data) => ScanData.fromJson(data)).toList();
        logCallback('Loaded ${scannedData.length} saved records', LogType.success);
      }
      
      if (pendingRowString != null) {
        pendingRow = ScanData.fromJson(jsonDecode(pendingRowString));
        logCallback('Loaded pending row from storage', LogType.success);
      }
      
      return {
        'scannedData': scannedData,
        'pendingRow': pendingRow,
      };
    } catch (e) {
      logCallback('Error loading saved data: $e', LogType.error);
      return {
        'scannedData': <ScanData>[],
        'pendingRow': null,
      };
    }
  }

  /// Saves scanned data to local storage
  Future<void> saveData(List<ScanData> scannedData, ScanData? pendingRow) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save the scanned data list
      final List<Map<String, dynamic>> dataList = scannedData.map((data) => data.toJson()).toList();
      await prefs.setString('scanned_data', jsonEncode(dataList));
      
      // Save the pending row if it exists
      if (pendingRow != null) {
        await prefs.setString('pending_row', jsonEncode(pendingRow.toJson()));
      } else {
        await prefs.remove('pending_row');
      }
      
      logCallback('Data saved to local storage', LogType.success);
    } catch (e) {
      logCallback('Error saving data: $e', LogType.error);
    }
  }

  /// Downloads scanned data as CSV file
  Future<void> downloadCsv(List<ScanData> scannedData, ScanData? pendingRow) async {
    try {
      if (scannedData.isEmpty && pendingRow == null) {
        logCallback('No data to download', LogType.error);
        return;
      }
      
      final List<List<dynamic>> csvData = [
        ['Timestamp', 'QR Data', 'NFC Data'], // Header
      ];
      
      // Add all data rows
      for (var data in scannedData) {
        csvData.add([data.timestamp, data.qrData, data.nfcData]);
      }
      
      // Add pending row if exists
      if (pendingRow != null) {
        csvData.add([pendingRow.timestamp, pendingRow.qrData, pendingRow.nfcData]);
      }
      
      // Convert to CSV string
      final String csv = const ListToCsvConverter().convert(csvData);
      
      // Save directly to Downloads folder (Android only)
      if (Platform.isAndroid) {
        try {
          // Request storage permission again just to be sure
          var status = await Permission.storage.request();
          
          // Try to use the download directory directly (works on most devices)
          final directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }
          
          final fileName = 'scan_data_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
          final filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          await file.writeAsString(csv);
          
          logCallback('CSV file saved to Downloads folder', LogType.success);
          return;
        } catch (e) {
          logCallback('Error with default download: $e', LogType.error);
          
          // Fallback to app's external storage directory
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            final fileName = 'scan_data_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
            final filePath = '${externalDir.path}/$fileName';
            final file = File(filePath);
            await file.writeAsString(csv);
            
            logCallback('CSV file saved to app external storage', LogType.success);
            return;
          } else {
            throw Exception('Could not access external storage');
          }
        }
      } else {
        // For iOS, we'll use the application documents directory
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'scan_data_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsString(csv);
        
        logCallback('CSV file saved to app documents folder', LogType.success);
      }
    } catch (e) {
      logCallback('Error saving CSV: $e', LogType.error);
    }
  }
} 