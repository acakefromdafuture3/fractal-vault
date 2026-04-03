import 'package:cloud_firestore/cloud_firestore.dart';

class SecurityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. THE LIVE DATA PIPELINE (For Tista's Home Screen)
  Stream<Map<String, dynamic>> getSystemStats() {
    return _db
        .collection('system_stats')
        .doc('current_status')
        .snapshots() 
        .map((snapshot) {
      
      if (snapshot.exists && snapshot.data() != null) {
        return snapshot.data() as Map<String, dynamic>;
      } else {
        // Safe fallback when the database is completely empty
        return {
          'securityScore': 0,
          'totalFiles': 0,
          'activeShards': 0,
          'threatsBlocked': 0,
          'lastScan': '--:--', 
        };
      }
    });
  }
}