import 'package:cloud_firestore/cloud_firestore.dart';

class VaultService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Fetch ALL files (Live Stream)
  Stream<List<Map<String, dynamic>>> getVaultFiles() {
    return _db
        .collection('vault_files')
        .orderBy('dateAdded', descending: true) // Sorts newest to oldest
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        var data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();
    });
  }

  // 2. Fetch ONLY "Recently Used" files (Live Stream)
  Stream<List<Map<String, dynamic>>> getRecentFiles() {
    return _db
        .collection('vault_files')
        .orderBy('lastAccessed', descending: true) // Sorts by recently touched
        .limit(3) // The Firebase version of .take(3)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        var data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();
    });
  }
}