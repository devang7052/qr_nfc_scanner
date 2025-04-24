class RfidUtils {
  /// Converts a raw RFID number to the formatted tag ID string
  static String convertRfidFormat(String rawData) {
    try {
      // Try to parse the raw input as an integer
      int rfidNumber = int.tryParse(rawData.trim()) ?? 0;
      
      if (rfidNumber == 0) {
        return 'Tag ID: $rawData'; // Return original if parsing fails
      }
      
      // Convert the number into 4 bytes (little-endian)
      List<int> bytes = [
        rfidNumber & 0xFF,
        (rfidNumber >> 8) & 0xFF,
        (rfidNumber >> 16) & 0xFF,
        (rfidNumber >> 24) & 0xFF,
      ];
      
      // Append the constant [1, 0, 1]
      bytes.addAll([1, 0, 1]);
      
      // Convert to colon-separated hex string
      String tagId = bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join(':').toLowerCase();
      
      return 'Tag ID: $tagId';
    } catch (e) {
      return 'Tag ID: $rawData'; // Return original on error
    }
  }
} 