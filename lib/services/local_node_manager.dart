// Location: lib/services/local_node_manager.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class LocalNodeManager {
  
  /// 📂 Get the base directory for the Fractal Vault
  Future<String> _getVaultPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final String vaultPath = '${directory.path}/fractal_vault_hardware_storage';
    final Directory vaultDir = Directory(vaultPath);
    
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultPath;
  }

  /// 🔒 NODE 5 (The Burger): Secures the Full Encrypted File locally
  Future<bool> securePhysicalKey({required String fileId, required Uint8List shardBytes}) async {
    print("========================================");
    print("💾 SECURING ENCRYPTED FILE ON LOCAL NODE...");

    try {
      final String vaultPath = await _getVaultPath();
      final File fileEntry = File('$vaultPath/$fileId.bin');
      
      await fileEntry.writeAsBytes(shardBytes);

      print("✅ NODE 5: ENCRYPTED DATA STORED LOCALLY!");
      print("📍 Path: ${fileEntry.path}");
      return true;
      
    } catch (e) {
      print("❌ NODE 5 FILE ERROR: $e");
      return false;
    }
  }

  /// 🍟 NODE 5 (The Fry): Stores the 5th Key Shard locally
  /// This ensures the file is useless if someone steals your Cloud credentials
  /// but doesn't have your physical phone.
  Future<bool> storeLocalShard(String fileId, String keyShard) async {
    print("🔑 SECURING 5TH KEY SHARD ON HARDWARE...");

    try {
      final String vaultPath = await _getVaultPath();
      final File shardFile = File('$vaultPath/$fileId-shard5.txt');
      
      await shardFile.writeAsString(keyShard);

      print("✅ NODE 5: MASTER SHARD 5 SECURED!");
      print("========================================");
      return true;
    } catch (e) {
      print("❌ NODE 5 SHARD ERROR: $e");
      return false;
    }
  }

  /// 📥 RETRIEVAL: Fetch the local shard for reconstruction
  Future<String?> getLocalShard(String fileId) async {
    try {
      final String vaultPath = await _getVaultPath();
      final File shardFile = File('$vaultPath/$fileId-shard5.txt');
      
      if (await shardFile.exists()) {
        return await shardFile.readAsString();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}