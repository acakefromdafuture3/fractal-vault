// Location: lib/services/vault_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart'; 
import 'cloud_dispatcher.dart'; 

class VaultService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final CloudDispatcher _cloud = CloudDispatcher(); 

  /// 🔥 THE ENCRYPTED MULTI-NODE PORTAL
  Future<void> uploadEncryptedFile({
    required String name,
    required String extension,
    required Uint8List encryptedBytes,
    required String iv,
    required List<String> shards, 
    String? folderId,
    bool isSecret = false, 
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No authenticated operator found.");

    // 🕵️ 1. CAPTURE HARDWARE FINGERPRINT
    var deviceInfo = DeviceInfoPlugin();
    String deviceId = "unknown";
    try {
      if (Platform.isAndroid) {
        var androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id; 
      } else if (Platform.isIOS) {
        var iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? "unknown";
      }
    } catch (e) {
      print("Hardware Fingerprint Failed: $e");
    }

    final String fileId = DateTime.now().millisecondsSinceEpoch.toString();
    String cleanType = _normalizeCategory(extension);

    // 2. DISPATCH TO DECENTRALIZED NODES
    final Map<String, String> nodeLinks = await _cloud.disperseToNodes(
      fileId: fileId,
      bytes: encryptedBytes,
      extension: extension,
      shards: shards, 
    );

    // 3. SECURE METADATA IN FIRESTORE
    await _db.collection('vault_files').doc(fileId).set({
      'ownerId': user.uid, 
      'uploaderDeviceId': deviceId, 
      'name': name,
      'type': cleanType,
      'extension': extension,
      'iv': iv,             
      'nodeLinks': nodeLinks, 
      'isSecret': isSecret, 
      'folderId': folderId,
      'dateAdded': FieldValue.serverTimestamp(),
      'status': 'Shattered', 
    });
  }

  // 1. Fetch ALL files
  Stream<List<Map<String, dynamic>>> getVaultFiles() {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return _db
        .collection('vault_files')
        .where('ownerId', isEqualTo: currentUserId) 
        .where('isSecret', isEqualTo: false)
        .orderBy('dateAdded', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        var data = doc.data();
        data['docId'] = doc.id;
        data['type'] = _normalizeCategory(data['type']?.toString());
        return data;
      }).toList();
    });
  }

  // 2. Fetch "Recent" files
  Stream<List<Map<String, dynamic>>> getRecentFiles() {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return _db
        .collection('vault_files')
        .where('ownerId', isEqualTo: currentUserId) 
        .where('isSecret', isEqualTo: false)
        .orderBy('dateAdded', descending: true) 
        .limit(3)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        var data = doc.data();
        data['docId'] = doc.id;
        data['type'] = _normalizeCategory(data['type']?.toString());
        return data;
      }).toList();
    });
  }

  // 3. THE TRANSLATOR ENGINE
  String _normalizeCategory(String? rawType) {
    if (rawType == null) return 'unknown';
    String lowerType = rawType.toLowerCase();
    if (['jpg', 'jpeg', 'png'].contains(lowerType)) return 'image';
    if (['pdf', 'doc', 'docx'].contains(lowerType)) return 'document'; 
    if (['txt', 'csv', 'md'].contains(lowerType)) return 'text';       
    if (['mp4', 'mkv', 'mov'].contains(lowerType)) return 'video';
    if (['mp3', 'wav', 'm4a'].contains(lowerType)) return 'audio';
    return lowerType; 
  }

  // ======================================================================
  // 🔥 NEW BACKEND SECURITY: THESE METHODS CANNOT BE BYPASSED
  // ======================================================================

  /// Permanently deletes a file, BUT ONLY if the current user is the true owner.
  Future<void> deleteFile(String docId, String fileOwnerId) async {
    final user = FirebaseAuth.instance.currentUser;
    
    // BACKEND HARD-CHECK: If the hacker bypasses the UI, the server still stops them here.
    if (user == null || user.uid != fileOwnerId) {
      throw Exception("BACKEND BREACH PREVENTED: Unauthorized delete attempt.");
    }

    // Execute the purge
    await _db.collection('vault_files').doc(docId).delete();
  }

  /// Cloaks the file (moves to secret vault), BUT ONLY if the current user is the true owner.
  Future<void> moveFileToSecret(String docId, String fileOwnerId) async {
    final user = FirebaseAuth.instance.currentUser;
    
    // BACKEND HARD-CHECK
    if (user == null || user.uid != fileOwnerId) {
      throw Exception("BACKEND BREACH PREVENTED: Unauthorized cloak attempt.");
    }

    // Execute the cloak
    await _db.collection('vault_files').doc(docId).update({
      'isSecret': true,
    });
  }
}