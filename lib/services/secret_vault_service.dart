import 'package:cloud_firestore/cloud_firestore.dart';

class SecretVaultService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ONLY fetches files where isSecret is TRUE
  Stream<List<Map<String, dynamic>>> getSecretFiles() {
    return _db
        .collection('vault_files')
        .where('isSecret', isEqualTo: true) // 🔒 THE VIP FILTER
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