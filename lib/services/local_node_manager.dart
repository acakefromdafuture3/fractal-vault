import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class LocalNodeManager {
  
  /// 🔒 Secures the 5th Shard on the physical hardware
  Future<bool> securePhysicalKey({required String fileId, required Uint8List shardBytes}) async {
    print("========================================");
    print("💾 SECURING SHARD 5 ON LOCAL HARDWARE...");

    try {
      // 1. Get the hidden, app-specific document directory
      final directory = await getApplicationDocumentsDirectory();
      final String vaultPath = '${directory.path}/fractal_vault_hardware_keys';
      
      // 2. Create the hidden Vault directory if it doesn't exist
      final Directory vaultDir = Directory(vaultPath);
      if (!await vaultDir.exists()) {
        await vaultDir.create(recursive: true);
      }

      // 3. Write the raw mathematical bytes to the disk
      final File shardFile = File('$vaultPath/$fileId-shard5.bin');
      await shardFile.writeAsBytes(shardBytes);

      print("✅ NODE 5 (LOCAL): PHYSICAL KEY SECURED!");
      print("📍 Hardware Path: ${shardFile.path}");
      print("========================================");
      return true;
      
    } catch (e) {
      print("❌ NODE 5 FAILED: $e");
      return false;
    }
  }
}