import 'dart:typed_data';
import 'package:shamir_secret_plg/shamir_secret_plg.dart';
import 'dart:convert'; // For converting bytes back to text

class ReconstructionEngine {
  // Using the exact same algorithm class to reverse the math
  final IShamir _shamir = ShamirClaude01();

  /// 🧬 Takes a list of 3 or more shards and rebuilds the file
  Uint8List? rebuildFile(List<Uint8List> activeShards) {
    print("========================================");
    print("🧬 RECONSTRUCTION ENGINE ACTIVATED...");
    print("📥 Received ${activeShards.length} shards for assembly.");

    try {
      // The math engine fuses the shards together
      Uint8List? originalBytes = _shamir.combine(activeShards);
      
      if (originalBytes != null) {
        print("✅ RECONSTRUCTION SUCCESSFUL!");
        print("📏 Restored File Size: ${originalBytes.lengthInBytes} bytes");
        
        // Let's print the actual text to prove it's the real file!
        String restoredText = utf8.decode(originalBytes);
        print("📄 FILE CONTENTS: '$restoredText'");
        print("========================================");
        
        return originalBytes;
      } else {
        print("❌ FAILED: The math did not align. Are these the correct shards?");
        return null;
      }
    } catch (e) {
      print("❌ RECONSTRUCTION ERROR: $e");
      return null;
    }
  }
}