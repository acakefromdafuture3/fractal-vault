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

  // 🔥 2. THE BREACH LOGGING PORTAL (New!)
  Future<void> logBreachAttempt({
    required String target,
    required String ipAddress,
    required String location,
    required String deviceType,
  }) async {
    try {
      // Step A: Save the detailed log for the Security Logs Screen
      await _db.collection('security_logs').add({
        'target': target,
        'ipAddress': ipAddress,
        'location': location,
        'deviceType': deviceType,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'BLOCKED',
      });

      // Step B: Automatically increment the 'threatsBlocked' stat for the Home Screen!
      await _db.collection('system_stats').doc('current_status').set({
        'threatsBlocked': FieldValue.increment(1),
      }, SetOptions(merge: true));

    } catch (e) {
      // We use print here instead of debugPrint so you don't have to import flutter/material
      print("Backend Error - Failed to log breach: $e");
    }
  }
  // 🔥 2.5 THE AUTHORIZED LOGGING PORTAL
  Future<void> logAuthorizedAccess({
    required String target,
    required String ipAddress,
    required String location,
    required String deviceType,
    required String accessedBy, // E.g., "Tista" or "Admin"
  }) async {
    try {
      await _db.collection('security_logs').add({
        'target': target,
        'ipAddress': ipAddress,
        'location': location,
        'deviceType': deviceType,
        'accessedBy': accessedBy,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'GRANTED', // 🔥 This word tells the UI to put it in the Green Tab!
      });
    } catch (e) {
      print("Backend Error - Failed to log authorized access: $e");
    }
  }

  // 🔥 3. FETCH SECURITY LOGS (For Tista's New Screen)
  Stream<List<Map<String, dynamic>>> getSecurityLogs() {
    return _db
        .collection('security_logs')
        .orderBy('timestamp', descending: true) // Newest attacks first
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        var data = doc.data();
        data['logId'] = doc.id; // Always good practice to pass the ID
        return data;
      }).toList();
    });
  }
}