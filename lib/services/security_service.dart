import 'package:cloud_firestore/cloud_firestore.dart';

class SecurityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. THE LIVE DATA PIPELINE (For Tista's Home Screen)
  Stream<Map<String, dynamic>> getSystemStats() {
    return _db
        .collection('system_stats')
        .doc('current_status')
        .snapshots() // This is the magic word that keeps the pipe open
        .map((snapshot) {
      
      if (snapshot.exists && snapshot.data() != null) {
        return snapshot.data() as Map<String, dynamic>;
      } else {
        // Safe fallback if the database is completely empty
        return {
          'securityScore': 0,
          'totalFiles': 0,
          'activeShards': 0,
          'threatsBlocked': 0,
          'lastScan': 'System Offline',
        };
      }
    });
  }

  // 2. THE INITIALIZER (Run this ONCE to set up the database)
  Future<void> initializeDefaultStats() async {
    final docRef = _db.collection('system_stats').doc('current_status');
    
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      await docRef.set({
        'securityScore': 98,
        'totalFiles': 14,
        'activeShards': 56,
        'threatsBlocked': 2,
        'lastScan': '19:30',
      });
      print("System: Database initialized with default vault stats.");
    }
  }
}