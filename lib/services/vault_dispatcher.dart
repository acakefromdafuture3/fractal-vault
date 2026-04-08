// Location: lib/services/vault_dispatcher.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'encryption_service.dart';
import 'vault_service.dart'; // Assuming this handles your Firestore/Node uploads

class VaultDispatcher {
  
  /// The Unified Secure Upload Pipeline
  /// This can be called from ANY screen (Dashboard, Category, or Secret Vault)
  static Future<void> initiateSecureUpload(BuildContext context, {String? folderId, bool isSecret = false}) async {
    try {
      // 1. Unified File Picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'pdf', 'png', 'jpg', 'jpeg'],
      );

      if (result == null || result.files.single.path == null) return;

      // 2. Metadata Extraction
      String filePath = result.files.single.path!;
      String fileName = result.files.single.name;
      String ext = result.files.single.extension ?? fileName.split('.').last;

      // 3. Cryptographic Execution
      final engine = EncryptionService();
      final fileBytes = await File(filePath).readAsBytes();
      
      final aesKey = engine.generateMasterAesKey();
      final encryptedData = engine.encryptHeavyFile(fileBytes, aesKey);
      final keyShards = engine.shredAesKey(aesKey);

      // 4. Node Distribution (Pushing to Supabase, Appwrite, etc.)
      await VaultService().uploadEncryptedFile(
        name: fileName,
        extension: ext,
        encryptedBytes: encryptedData['encryptedBytes'],
        iv: encryptedData['iv'],
        shards: keyShards,
        folderId: folderId,
        isSecret: isSecret,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ $fileName secured and scattered."), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Upload Failed: $e"), backgroundColor: Colors.redAccent)
        );
      }
    }
  }
}