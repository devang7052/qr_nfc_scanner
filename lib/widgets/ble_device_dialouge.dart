import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleDeviceDialog extends StatefulWidget {
  final Future<List<ScanResult>> Function() startScan;
  final Function(BluetoothDevice) onDeviceSelected;

  const BleDeviceDialog({
    Key? key,
    required this.startScan,
    required this.onDeviceSelected,
  }) : super(key: key);

  @override
  State<BleDeviceDialog> createState() => _BleDeviceDialogState();
}

class _BleDeviceDialogState extends State<BleDeviceDialog> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Use Future.microtask to delay the scan until after the build is complete
    Future.microtask(() => _startScan());
  }

  void _startScan() async {
    if (!mounted) return;
    
    setState(() {
      _isScanning = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final results = await widget.startScan();
      
      if (!mounted) return;
      
      setState(() {
        _scanResults = results;
        _isScanning = false;
      });

      if (results.isEmpty) {
        if (!mounted) return;
        
        setState(() {
          _hasError = true;
          _errorMessage = 'No BLE devices found. Make sure your device is powered on and nearby.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isScanning = false;
        _hasError = true;
        _errorMessage = 'Error scanning: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select BLE Device'),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildDialogContent(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_scanResults.isNotEmpty && !_isScanning)
          TextButton(
            onPressed: _startScan,
            child: const Text('Scan Again'),
          ),
      ],
    );
  }

  Widget _buildDialogContent() {
    if (_isScanning) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Scanning for BLE devices...'),
              const SizedBox(height: 8),
              const Text('This may take up to 10 seconds', 
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Text('Make sure your device is powered on and in range.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              const Text(
                'Troubleshooting tips:\n'
                '• Ensure Bluetooth is turned on\n'
                '• Make sure your device is powered on\n'
                '• Move closer to the device\n'
                '• Restart the BLE device',
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _startScan,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_scanResults.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bluetooth_disabled, color: Colors.grey, size: 48),
              const SizedBox(height: 16),
              const Text('No BLE devices found', 
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Troubleshooting tips:\n'
                '• Ensure Bluetooth is turned on\n'
                '• Make sure your device is powered on\n'
                '• Move closer to the device\n'
                '• Restart the BLE device',
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _startScan,
                child: const Text('Scan Again'),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Found ${_scanResults.length} devices',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _scanResults.length,
              itemBuilder: (context, index) {
                final result = _scanResults[index];
                final device = result.device;
                
                // Get the device name from either advName or advertisementData
                final name = device.advName.isNotEmpty
                    ? device.advName
                    : result.advertisementData.localName.isNotEmpty
                        ? result.advertisementData.localName
                        : 'Unknown Device ${device.id.id.substring(0, 6)}';
                        
                final rssi = result.rssi;
                
                // Determine signal strength indicator
                String signalStrength;
                Color signalColor;
                
                if (rssi > -60) {
                  signalStrength = 'Excellent';
                  signalColor = Colors.green;
                } else if (rssi > -70) {
                  signalStrength = 'Good';
                  signalColor = Colors.lightGreen;
                } else if (rssi > -80) {
                  signalStrength = 'Fair';
                  signalColor = Colors.orange;
                } else {
                  signalStrength = 'Poor';
                  signalColor = Colors.red;
                }
                
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: ListTile(
                    title: Text(name),
                    subtitle: Row(
                      children: [
                        // Text('Signal: $rssi dBm'),
                        // const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: signalColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: signalColor),
                          ),
                          child: Text(
                            signalStrength,
                            style: TextStyle(
                              fontSize: 10,
                              color: signalColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    leading: Icon(Icons.bluetooth, color: signalColor),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onDeviceSelected(device);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}