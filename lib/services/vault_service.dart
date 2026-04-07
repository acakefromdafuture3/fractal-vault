import 'package:cloud_firestore/cloud_firestore.dart';

class VaultService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🔥 THE MASTER UPLOAD PORTAL (Ritankar takes control!)
  Future<void> uploadFile({
    required String name,
    required String path,
    required String extension,
    required int size,
    required bool isSecret,
    String? folderId, // 🔥 ADDED: Optional parameter for Tista's new Folder feature!
  }) async {
    
    // 1. You handle the translation automatically!
    String cleanType = _normalizeCategory(extension);

    // 2. You safely write it to the database with all required fields
    await _db.collection('vault_files').add({
      'name': name,
      'path': path,
      'type': cleanType,
      'extension': extension, 
      'size': size,
      'status': 'Secured',
      'isSecret': isSecret, 
      'folderId': folderId, // 🔥 ADDED: Saves it safely to the database
      'dateAdded': FieldValue.serverTimestamp(),
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