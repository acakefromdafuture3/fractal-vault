import 'dart:typed_data';
import 'package:shamir_secret_plg/shamir_secret_plg.dart';

class ShredderEngine {
  // 🔥 THE FIX: Use the specific implementation class from the package
  final IShamir _shamir = ShamirClaude01();

  // 2. The core shredding function
  List<Uint8List> sliceFile(Uint8List originalFileBytes) {
    print("🔪 Shredder Engine Activated...");
    
    // The magic happens here: totalShares is 5, threshold is 3
    List<Uint8List>? shards = _shamir.split(
      originalFileBytes,
      totalShares: 5,
      threshold: 3,
    );

    // 3. Safety check
    if (shards == null || shards.length != 5) {
      throw Exception("Shredding failed! Math did not compute.");
    }

    print("✅ Successfully generated 5 Shamir Shards!");
    return shards;
  }
}