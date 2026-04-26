// Location: lib/services/security_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SecurityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Helper to safely get the current account's UID
  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? 'UNKNOWN_USER';

  // 🔥 1. THE BREACH LOGGING PORTAL
  Future<void> logBreachAttempt({
    required String target,
    required String ipAddress,
    required String location,
    required String deviceType,
  }) async {
    if (_currentUid == 'UNKNOWN_USER') return;

    try {
      await _db.collection('security_logs').add({
        'ownerId': _currentUid, // 🔒 FIXED: Matches Home Screen & Vault Files perfectly
        'target': target,
        'ipAddress': ipAddress,
        'location': location,
        'deviceType': deviceType,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'BLOCKED',
        'isThreat': true, // Helps us easily filter threats later
      });
      print("System: Breach logged successfully for $_currentUid");
    } catch (e) {
      print("Backend Error - Failed to log breach: $e");
    }
  }

  // 🔥 2. THE AUTHORIZED LOGGING PORTAL
  Future<void> logAuthorizedAccess({
    required String target,
    required String ipAddress,
    required String location,
    required String deviceType,
    required String accessedBy, 
  }) async {
    if (_currentUid == 'UNKNOWN_USER') return;

    try {
      await _db.collection('security_logs').add({
        'ownerId': _currentUid, // 🔒 FIXED
        'target': target,
        'ipAddress': ipAddress,
        'location': location,
        'deviceType': deviceType,
        'accessedBy': accessedBy,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'GRANTED',
        'isThreat': false, 
      });
    } catch (e) {
      print("Backend Error - Failed to log authorized access: $e");
    }
  }

  // 🔥 3. FETCH SECURITY LOGS (Filters out other people's logs!)
  Stream<List<Map<String, dynamic>>> getSecurityLogs() {
    return _db
        .collection('security_logs')
        .where('ownerId', isEqualTo: _currentUid) // 🔒 FIXED: Only grabs THIS account's logs
        .snapshots()
        .map((snapshot) {
      var logs = snapshot.docs.map((doc) {
        var data = doc.data();
        data['logId'] = doc.id; 
        return data;
      }).toList();

      // 🔥 Sort logs in Dart to avoid needing a complex Firebase Composite Index
      logs.sort((a, b) {
        Timestamp? timeA = a['timestamp'] as Timestamp?;
        Timestamp? timeB = b['timestamp'] as Timestamp?;
        if (timeA == null || timeB == null) return 0;
        return timeB.compareTo(timeA); // Newest at the top
      });

      return logs;
    });
  }

  // 🔥 4. THE LOG PURGE PROTOCOL 
  Future<void> deleteSecurityLog(String logId) async {
    try {
      await _db.collection('security_logs').doc(logId).delete();
      print("System: Security log $logId has been scrubbed.");
    } catch (e) {
      print("Backend Error - Failed to scrub log: $e");
    }
  }
}