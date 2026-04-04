import 'package:cloud_firestore/cloud_firestore.dart';

class VaultService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Fetch ALL files (With On-Read Translation!)
  Stream<List<Map<String, dynamic>>> getVaultFiles() {
    return _db
        .collection('vault_files')
        .orderBy('dateAdded', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        var data = doc.data();
        data['docId'] = doc.id;
        
        // THE INTERCEPTOR: Clean up the data before the UI sees it
        data['type'] = _normalizeCategory(data['type']?.toString());

        return data;
      }).toList();
    });
  }

  // 2. Fetch "Recently Used" files (With On-Read Translation!)
  Stream<List<Map<String, dynamic>>> getRecentFiles() {
    return _db
        .collection('vault_files')
        .orderBy('lastAccessed', descending: true)
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
    if (['pdf', 'doc', 'docx'].contains(lowerType)) return 'document'; // Removed 'txt' from here!
    if (['txt', 'csv', 'md'].contains(lowerType)) return 'text';       // Added the dedicated text row!
    if (['mp4', 'mkv', 'mov'].contains(lowerType)) return 'video';
    if (['mp3', 'wav', 'm4a'].contains(lowerType)) return 'audio';
    
    // If it already matches perfectly, let it through
    return lowerType; 
  }
}