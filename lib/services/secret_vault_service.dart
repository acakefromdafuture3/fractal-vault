// Location: lib/services/secret_vault_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🔥 NEEDED FOR IDENTITY

class SecretVaultService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Fetches ONLY files where isSecret is TRUE, belongs to YOU, and isn't PURGED
  Stream<List<Map<String, dynamic>>> getSecretFiles() {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return _db
        .collection('vault_files')
        .where('ownerId', isEqualTo: currentUserId) // 🔐 SATISFIES THE FIRESTORE RULE
        .where('isSecret', isEqualTo: true) // 🔒 THE VIP FILTER
        .where('status', isNotEqualTo: 'PURGED') // 👻 PATH B: HIDES DESTROYED FILES
        .orderBy('status') // 🔥 REQUIRED BY FIRESTORE FOR isNotEqualTo
        .orderBy('dateAdded', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        var data = doc.data();
        data['docId'] = doc.id;
        
        // Basic translation just in case
        String? rawType = data['type']?.toString();
        if (rawType != null) {
             String lower = rawType.toLowerCase();
             if (['jpg', 'jpeg', 'png'].contains(lower)) data['type'] = 'image';
             else if (['pdf', 'doc', 'docx'].contains(lower)) data['type'] = 'document'; 
             else if (['txt', 'csv', 'md'].contains(lower)) data['type'] = 'text';      
             else if (['mp4', 'mkv', 'mov'].contains(lower)) data['type'] = 'video';
             else if (['mp3', 'wav', 'm4a'].contains(lower)) data['type'] = 'audio';
        }
        
        return data;
      }).toList();
    });
  }
}