// Location: lib/services/security_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🔥 NEEDED TO IDENTIFY THE ACCOUNT

class SecurityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Helper to safely get the current account's UID
  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? 'UNKNOWN_USER';

  // 1. THE LIVE DATA PIPELINE (Isolated per user!)
  Stream<Map<String, dynamic>> getSystemStats() {
    return _db
        .collection('system_stats')
        .doc(_currentUid) // 🔥 Saves stats specific to THIS account
        .snapshots() 
        .map((snapshot) {
      
      if (snapshot.exists && snapshot.data() != null) {
        return snapshot.data() as Map<String, dynamic>;
      } else {
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

  // 🔥 2. THE BREACH LOGGING PORTAL
  Future<void> logBreachAttempt({
    required String target,
    required String ipAddress,
    required String location,
    required String deviceType,
  }) async {
    try {
      await _db.collection('security_logs').add({
        'ownerUid': _currentUid, // 🔥 TAGS THE LOG TO THE ACCOUNT BEING HACKED
        'target': target,
        'ipAddress': ipAddress,
        'location': location,
        'deviceType': deviceType,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'BLOCKED',
      });

      await _db.collection('system_stats').doc(_currentUid).set({
        'threatsBlocked': FieldValue.increment(1),
      }, SetOptions(merge: true));

    } catch (e) {
      print("Backend Error - Failed to log breach: $e");
    }
  }

  // 🔥 2.5 THE AUTHORIZED LOGGING PORTAL
  Future<void> logAuthorizedAccess({
    required String target,
    required String ipAddress,
    required String location,
    required String deviceType,
    required String accessedBy, 
  }) async {
    try {
      await _db.collection('security_logs').add({
        'ownerUid': _currentUid, // 🔥 TAGS THE LOG TO THE ACCOUNT
        'target': target,
        'ipAddress': ipAddress,
        'location': location,
        'deviceType': deviceType,
        'accessedBy': accessedBy,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'GRANTED', 
      });
    } catch (e) {
      print("Backend Error - Failed to log authorized access: $e");
    }
  }

  // 🔥 3. FETCH SECURITY LOGS (Filters out other people's logs!)
  Stream<List<Map<String, dynamic>>> getSecurityLogs() {
    return _db
        .collection('security_logs')
        .where('ownerUid', isEqualTo: _currentUid) // 🔥 ONLY GRAB THIS ACCOUNT'S LOGS
        .snapshots()
        .map((snapshot) {
      var logs = snapshot.docs.map((doc) {
        var data = doc.data();
        data['logId'] = doc.id; 
        return data;
      }).toList();

      // 🔥 We sort the logs here in Dart so Firebase doesn't crash asking for a "Composite Index"
      logs.sort((a, b) {
        Timestamp? timeA = a['timestamp'] as Timestamp?;
        Timestamp? timeB = b['timestamp'] as Timestamp?;
        if (timeA == null || timeB == null) return 0;
        return timeB.compareTo(timeA); // Puts newest at the top
      });

      return logs;
    });
  }

  // 🔥 4. THE LOG PURGE PROTOCOL 
  Future<void> deleteSecurityLog(String logId) async {
    try {
      await _db.collection('security_logs').doc(logId).delete();
      print("System: Security log $logId has been scrubbed from the database.");
    } catch (e) {
      print("Backend Error - Failed to scrub log: $e");
    }
  }
}