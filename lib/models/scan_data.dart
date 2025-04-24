import 'package:intl/intl.dart';

class ScanData {
  final String timestamp;
  final String qrData;
  final String nfcData;

  ScanData({
    required this.timestamp,
    this.qrData = '',
    this.nfcData = '',
  });

  Map<String, String> toMap() {
    return {
      'Timestamp': timestamp,
      'QR Data': qrData,
      'NFC Data': nfcData,
    };
  }
  
  // Methods for serialization/deserialization
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'qrData': qrData,
      'nfcData': nfcData,
    };
  }
  
  factory ScanData.fromJson(Map<String, dynamic> json) {
    return ScanData(
      timestamp: json['timestamp'] ?? '',
      qrData: json['qrData'] ?? '',
      nfcData: json['nfcData'] ?? '',
    );
  }
} 