import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cloud_dispatcher.dart'; 

class VaultService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CloudDispatcher _cloud = CloudDispatcher(); // Initialize your nodes

  /// 🔥 THE ENCRYPTED MULTI-NODE PORTAL
  /// 🔥 THE ENCRYPTED MULTI-NODE PORTAL
  // Location: lib/services/vault_service.dart

  /// 🔥 THE ENCRYPTED MULTI-NODE PORTAL (Upgraded to Decentralized)
  Future<void> uploadEncryptedFile({
    required String name,
    required String extension,
    required Uint8List encryptedBytes,
    required String iv,
    required List<String> shards, // These 5 shards will now be scattered
    String? folderId,
    bool isSecret = false, 
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No authenticated operator found.");

    final String fileId = DateTime.now().millisecondsSinceEpoch.toString();
    String cleanType = _normalizeCategory(extension);

    // 🔥 UPGRADE: We now pass the 'shards' to the cloud nodes instead of Firestore
    final Map<String, String> nodeLinks = await _cloud.disperseToNodes(
      fileId: fileId,
      bytes: encryptedBytes,
      extension: extension,
      shards: shards, // 🚀 Dispatching the shards!
    );

    // SECURE THE METADATA IN FIRESTORE (Keys are now GONE from here)
    await _db.collection('vault_files').doc(fileId).set({
      'ownerId': user.uid, 
      'name': name,
      'type': cleanType,
      'extension': extension,
      'iv': iv,             
      // 'shards': shards, ❌ REMOVED: Firestore no longer sees the key!
      'nodeLinks': nodeLinks, 
      'isSecret': isSecret, 
      'folderId': folderId,
      'dateAdded': FieldValue.serverTimestamp(),
      'status': 'Shattered', 
    });
  }

  // 1. Fetch ALL files (Sorted by dateAdded to match Tista's UI)
  Stream<List<Map<String, dynamic>>> getVaultFiles() {
    return _db
        .collection('vault_files')
        .where('isSecret', isEqualTo: false)
        .orderBy('dateAdded', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        var data = doc.data();
        data['docId'] = doc.id;
        
        // THE INTERCEPTOR: Acts as a safety net for manual Ghost Files
        data['type'] = _normalizeCategory(data['type']?.toString());

        return data;
      }).toList();
    });
  }

  // 2. Fetch "Recent" files (Now sorts by dateAdded to prevent crashes!)
  Stream<List<Map<String, dynamic>>> getRecentFiles() {
    return _db
        .collection('vault_files')
        .where('isSecret', isEqualTo: false)
        .orderBy('dateAdded', descending: true) 
        .limit(3)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        var data = doc.data();
        data['docId'] = doc.id;
        
        // THE INTERCEPTOR
        data['type'] = _normalizeCategory(data['type']?.toString());

        return data;
      }).toList();
    });
  }

  // 3. THE TRANSLATOR ENGINE (Hidden from the UI)
  String _normalizeCategory(String? rawType) {
    if (rawType == null) return 'unknown';
    
    String lowerType = rawType.toLowerCase();

    if (['jpg', 'jpeg', 'png'].contains(lowerType)) return 'image';
    if (['pdf', 'doc', 'docx'].contains(lowerType)) return 'document'; 
    if (['txt', 'csv', 'md'].contains(lowerType)) return 'text';       
    if (['mp4', 'mkv', 'mov'].contains(lowerType)) return 'video';
    if (['mp3', 'wav', 'm4a'].contains(lowerType)) return 'audio';
    
    // If Tista's code already mapped it to "image" or "document", it passes straight through
    return lowerType; 
  }
}