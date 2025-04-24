import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/log_message.dart';

class BleService {
  // Callback functions
  final Function(String, LogType) logCallback;
  final Function(String) onRfidSuccess;

  // BLE state variables
  BluetoothDevice? connectedDevice;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _notifySubscription;
  BluetoothCharacteristic? _rxCharacteristic;
  BluetoothCharacteristic? _txCharacteristic;
  
  // UART service and characteristic UUIDs (common for many BLE devices)
  final String UART_SERVICE_UUID = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  final String TX_CHARACTERISTIC_UUID = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"; // to device
  final String RX_CHARACTERISTIC_UUID = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; // from device
  
  // MTU size for chunking
  int mtuSize = 23; // Default minimum BLE MTU size
  
  // Lua code for RFID scanning
  final String rfidScanScript = '''function main()
  rfid_start_reading()
  local start_time = millis()
  local timeout = 10000

  while true do
    local success, uid = rfid_read_data()
    if success then
      buzzer_beep(100, 50, 1)
      local json_output = string.format(
                            '{"msgtype":"rfid","value":"%s","device":"Devices.memoryBoard"}',
                            uid)
      ble_print(json_output)
      rfid_stop_reading()
      clear_display()
      return true
    end

    if (millis() - start_time) > timeout then
      rfid_stop_reading()
      clear_display()
      return false
    end
    delay(200)
  end
end

main()
''';

  BleService({
    required this.logCallback,
    required this.onRfidSuccess,
  });

  /// Initialize BLE service
  Future<bool> initialize() async {
    try {
      // Check if Bluetooth is on
      if (await FlutterBluePlus.isSupported == false) {
        logCallback('Bluetooth not supported on this device', LogType.error);
        return false;
      }

      // Request location permission (required for BLE scanning on Android)
      var locationStatus = await Permission.location.request();
      if (!locationStatus.isGranted) {
        logCallback('Location permission required for BLE scanning', LogType.error);
        return false;
      }

      // Request Bluetooth permissions
      var bluetoothStatus = await Permission.bluetooth.request();
      var bluetoothScanStatus = await Permission.bluetoothScan.request();
      var bluetoothConnectStatus = await Permission.bluetoothConnect.request();
      
      if (!bluetoothStatus.isGranted || 
          !bluetoothScanStatus.isGranted || 
          !bluetoothConnectStatus.isGranted) {
        logCallback('Bluetooth permissions not granted', LogType.error);
        return false;
      }

      // Turn on Bluetooth if it's not on
      if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
        logCallback('Bluetooth is turned off. Please turn it on.', LogType.error);
        await FlutterBluePlus.turnOn();
        return false;
      }

      logCallback('BLE service initialized', LogType.success);
      return true;
    } catch (e) {
      logCallback('Error initializing BLE: $e', LogType.error);
      return false;
    }
  }

  /// Start scanning for BLE devices
  Future<List<ScanResult>> startScan({int timeoutSeconds = 10}) async {
    try {
      // Ensure Bluetooth is on
      if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.off) {
        logCallback('Bluetooth is turned off. Please turn it on.', LogType.error);
        await FlutterBluePlus.turnOn();
        return [];
      }
      
      // Make sure we're not already scanning
      if (await FlutterBluePlus.isScanning.first) {
        await FlutterBluePlus.stopScan();
      }
      
      logCallback('Scanning for BLE devices...', LogType.info);
      
      // Start scanning with longer timeout and higher power
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: timeoutSeconds),
        androidScanMode: AndroidScanMode.lowLatency,
      );
      
      // Wait for scan to complete
      await FlutterBluePlus.isScanning.where((val) => val == false).first;
      
      // Get the final results
      final results = await FlutterBluePlus.scanResults.first;
      
      logCallback('Scan complete. Found ${results.length} BLE devices', LogType.success);
      
      return results;
    } catch (e) {
      logCallback('Error scanning for BLE devices: $e', LogType.error);
      return [];
    }
  }

  /// Connect to a BLE device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      // Disconnect from any existing connection
      if (connectedDevice != null) {
        await disconnectDevice();
      }
      
      final deviceName = device.advName.isNotEmpty ? device.advName : 'device';
      logCallback('Connecting to $deviceName...', LogType.info);
      
      // Connect to device
      await device.connect(timeout: const Duration(seconds: 15));
      
      // Setup connection state listener
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          logCallback('Device disconnected: $deviceName', LogType.error);
          disconnectDevice();
        }
      });
      
      connectedDevice = device;
      
      // Discover services
      logCallback('Discovering services for $deviceName...', LogType.info);
      List<BluetoothService> services = await device.discoverServices();
      
      // Try to request higher MTU if supported
      try {
        int negotiatedMtu = await device.requestMtu(512);
        logCallback('Negotiated MTU: $negotiatedMtu', LogType.success);
        mtuSize = negotiatedMtu;
      } catch (e) {
        logCallback('Could not request higher MTU: $e', LogType.error);
        // Continue with default MTU
      }
      
      // Find UART service and characteristics
      bool foundUartService = false;
      for (var service in services) {
        final serviceUuid = service.uuid.toString().toLowerCase();
        final serviceUuidNoHyphens = serviceUuid.replaceAll('-', '');
        final targetUuidNoHyphens = UART_SERVICE_UUID.replaceAll('-', '');
        
        if (serviceUuid == UART_SERVICE_UUID || serviceUuidNoHyphens == targetUuidNoHyphens) {
          foundUartService = true;
          logCallback('Found UART service', LogType.success);
          
          for (var characteristic in service.characteristics) {
            final charUuid = characteristic.uuid.toString().toLowerCase();
            final charUuidNoHyphens = charUuid.replaceAll('-', '');
            final targetTxUuidNoHyphens = TX_CHARACTERISTIC_UUID.replaceAll('-', '');
            final targetRxUuidNoHyphens = RX_CHARACTERISTIC_UUID.replaceAll('-', '');
            
            // TX characteristic (write to device)
            if (charUuid == TX_CHARACTERISTIC_UUID || charUuidNoHyphens == targetTxUuidNoHyphens) {
              _txCharacteristic = characteristic;
              logCallback('Found TX characteristic', LogType.success);
            } 
            // RX characteristic (receive from device)
            else if (charUuid == RX_CHARACTERISTIC_UUID || charUuidNoHyphens == targetRxUuidNoHyphens) {
              _rxCharacteristic = characteristic;
              logCallback('Found RX characteristic', LogType.success);
              
              // Subscribe to notifications
              await characteristic.setNotifyValue(true);
              _notifySubscription = characteristic.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  _handleReceivedData(value);
                }
              });
            }
          }
        }
      }
      
      if (!foundUartService || _txCharacteristic == null) {
        logCallback('Required services not found on device', LogType.error);
        await disconnectDevice();
        return false;
      }
      
      logCallback('Connected to $deviceName', LogType.success);
      return true;
    } catch (e) {
      logCallback('Error connecting to device: $e', LogType.error);
      await disconnectDevice();
      return false;
    }
  }

  /// Disconnect from the BLE device
  Future<void> disconnectDevice() async {
    try {
      // Cancel subscriptions
      await _notifySubscription?.cancel();
      _notifySubscription = null;
      
      await _connectionSubscription?.cancel();
      _connectionSubscription = null;
      
      // Disconnect device
      if (connectedDevice != null) {
        await connectedDevice!.disconnect();
        logCallback('Disconnected from device', LogType.success);
      }
      
      // Reset variables
      connectedDevice = null;
      _rxCharacteristic = null;
      _txCharacteristic = null;
    } catch (e) {
      logCallback('Error disconnecting: $e', LogType.error);
    }
  }

  /// Send Lua script to start RFID scanning - using the reference approach
  Future<bool> sendRfidScanScript() async {
    if (connectedDevice == null || _txCharacteristic == null) {
      logCallback('No connected device', LogType.error);
      return false;
    }
    
    try {
      // First, stop any running Lua code
      await stopLuaCode();
      
      // Give the device a moment to process
      await Future.delayed(Duration(milliseconds: 300));
      
      logCallback('Sending RFID scan script to device...', LogType.info);
      
      // Replace newline literals with actual newlines (same as in reference code)
      String convertedScript = rfidScanScript.replaceAllMapped(RegExp(r'\\n'), (match) => '\n');
      
      // Send the script
      await writeWithResponse(convertedScript);
      
      // Send EOF character (0x04) to execute the script
      await writeWithResponse('\x04');
      
      logCallback('RFID scan script sent to device', LogType.success);
      return true;
    } catch (e) {
      logCallback('Error sending RFID scan script: $e', LogType.error);
      return false;
    }
  }

  /// Stop any running Lua code on the device - using the reference approach
  Future<void> stopLuaCode() async {
    if (_txCharacteristic == null) return;
    
    try {
      // Use Ctrl+A (0x01) to stop running code, exactly as in reference code
      logCallback('Stopping running Lua code...', LogType.info);
      await writeWithResponse('\x01');
      
      logCallback('Sent stop command to device', LogType.success);
    } catch (e) {
      logCallback('Error stopping Lua code: $e', LogType.error);
    }
  }

  /// Write to device with response - handles chunking as needed
  Future<void> writeWithResponse(String value) async {
    if (_txCharacteristic == null) return;
    
    try {
      // Calculate chunk size based on MTU
      int defaultChunkSize = mtuSize - 3; // Account for ATT overhead
      
      // If message is larger than the chunk size, split it
      if (value.length > defaultChunkSize) {
        logCallback('Message is too long, splitting it', LogType.info);
        
        int start = 0;
        int end = defaultChunkSize;
        
        while (end < value.length) {
          List<int> chunk = utf8.encode(value.substring(start, end));
          await _txCharacteristic!.write(chunk, withoutResponse: false);
          
          start = end;
          end += defaultChunkSize;
          
          // Small delay between chunks
          await Future.delayed(Duration(milliseconds: 10));
        }
        
        // Send the last chunk
        List<int> lastChunk = utf8.encode(value.substring(start));
        await _txCharacteristic!.write(lastChunk, withoutResponse: false);
      } else {
        // Send as a single chunk
        List<int> bytes = utf8.encode(value);
        await _txCharacteristic!.write(bytes, withoutResponse: false);
      }
    } catch (e) {
      logCallback('Error writing to device: $e', LogType.error);
      rethrow;
    }
  }

  /// Handle data received from the BLE device
  void _handleReceivedData(List<int> data) {
    try {
      String receivedString = utf8.decode(data);
      logCallback('Received from BLE: $receivedString', LogType.info);
      
      // Try to parse as JSON
      try {
        Map<String, dynamic> jsonData = jsonDecode(receivedString);
        
        // Check if this is RFID data
        if (jsonData.containsKey('msgtype') && jsonData['msgtype'] == 'rfid' && jsonData.containsKey('value')) {
          String rfidValue = jsonData['value'];
          
          if (rfidValue.isNotEmpty) {
            // Format the RFID value with colons between every two digits
            String formattedRfidValue = '';
            for (int i = 0; i < rfidValue.length; i += 2) {
              if (i + 2 <= rfidValue.length) {
                formattedRfidValue += rfidValue.substring(i, i + 2);
                if (i + 2 < rfidValue.length) {
                  formattedRfidValue += ':';
                }
              } else if (i < rfidValue.length) {
                // Handle odd length (shouldn't happen with proper RFID values)
                formattedRfidValue += rfidValue.substring(i);
              }
            }
            
            logCallback('RFID read from external scanner: $formattedRfidValue', LogType.success);
            
            // Format the tag ID in the required format without additional text
            String tagIdOnly = 'Tag ID: $formattedRfidValue';
            
            // Pass the data to the callback
            onRfidSuccess(tagIdOnly);
          }
        }
      } catch (e) {
        // Not valid JSON, just log the raw data
        logCallback('Received non-JSON data from BLE', LogType.info);
      }
    } catch (e) {
      logCallback('Error processing received data: $e', LogType.error);
    }
  }
}