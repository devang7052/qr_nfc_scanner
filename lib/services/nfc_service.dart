import 'dart:convert';
import 'package:nfc_manager/nfc_manager.dart';
import '../models/log_message.dart';

class NfcService {
  final Function(String, LogType) logCallback;
  final Function(String) onNfcSuccess;

  NfcService({
    required this.logCallback,
    required this.onNfcSuccess,
  });

  /// Initialize NFC manager
  Future<void> initialize() async {
    try {
      logCallback('NFC scanner initialized', LogType.success);
    } catch (e) {
      logCallback('NFC initialization error: $e', LogType.error);
    }
  }

  /// Start NFC scanning session
  Future<bool> startNfcSession() async {
    try {
      bool isAvailable = await NfcManager.instance.isAvailable();
      if (!isAvailable) {
        logCallback('NFC is disabled or not available. Please enable it in your device settings.', LogType.error);
        return false;
      }
      
      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          _processNfcTag(tag);
        },
      );
      
      logCallback('NFC scanner started', LogType.success);
      return true;
    } catch (e) {
      logCallback('Error starting NFC scanner: $e', LogType.error);
      return false;
    }
  }

  /// Stop NFC scanning session
  void stopNfcSession() {
    try {
      NfcManager.instance.stopSession();
      logCallback('NFC scanner stopped', LogType.success);
    } catch (e) {
      logCallback('Error stopping NFC scanner: $e', LogType.error);
    }
  }

  /// Process scanned NFC tag data
  void _processNfcTag(NfcTag tag) {
    String nfcText = '';
    
    try {
      // Log raw tag data to console for debugging
      logCallback('Raw NFC tag data: ${jsonEncode(tag.data)}', LogType.info);
      
      // If available, log specific raw identifier bytes
      final id = tag.data['nfca']?['identifier'] ?? tag.data['nfcb']?['identifier'] ?? tag.data['isodep']?['identifier'];
      if (id != null) {
        logCallback('Raw identifier bytes: $id', LogType.info);
        
        // Create string for display using standard format
        final String tagId = id.map((e) => e.toRadixString(16).padLeft(2, '0')).join(':').toLowerCase();
        nfcText = 'Tag ID: $tagId';
      } else {
        nfcText = 'Tag ID: unknown';
      }
      
      // Get NDEF data if available
      if (tag.data.containsKey('ndef')) {
        final ndef = tag.data['ndef'];
        // Log raw NDEF data
        logCallback('Raw NDEF data: ${jsonEncode(ndef)}', LogType.info);
        
        if (ndef != null && ndef['cachedMessage'] != null) {
          final message = ndef['cachedMessage']['records'];
          if (message != null && message is List) {
            for (final record in message) {
              if (record['payload'] != null) {
                // Log raw payload bytes
                final payload = record['payload'] as List<int>;
                logCallback('Raw payload bytes: $payload', LogType.info);
                
                String? text;
                
                if (record['typeNameFormat'] == 1 && record['type']?.contains(0x54) == true) { // Text record
                  final languageCodeLength = payload[0] & 0x3F;
                  // Convert to lowercase immediately when extracting text
                  text = String.fromCharCodes(payload.sublist(1 + languageCodeLength)).toLowerCase();
                } else {
                  // Convert to lowercase immediately when extracting text
                  text = String.fromCharCodes(payload).toLowerCase();
                }
                
                if (text != null && text.isNotEmpty) {
                  nfcText += '\ndata: ' + text;
                }
                
                if (record['type'] != null) {
                  nfcText += '\nrecord type: ${String.fromCharCodes(record['type']).toLowerCase()}';
                } else {
                  nfcText += '\nrecord type: unknown';
                }
              }
            }
          }
        }
      }
      
      if (nfcText.isNotEmpty) {
        logCallback('NFC Tag read: $nfcText', LogType.success);
        onNfcSuccess(nfcText);
      }
    } catch (e) {
      logCallback('Error processing NFC data: $e', LogType.error);
    }
  }
} 