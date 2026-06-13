// Location: lib/services/security_service.dart
//
// 🔒 SECURITY SERVICE — Fractal Vault threat logging backbone
//
// Changes in this revision:
//   • logAuthorizedAccess() now auto-fetches telemetry (no more hardcoded params)
//   • verifyHardwareOwnership() — single source of truth for the hardware lock,
//     used by SecurityLogsScreen and OperatorProfileScreen

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'telemetry_service.dart';

class SecurityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TelemetryService _telemetry = TelemetryService();

  /// Safely returns the current user's UID, or 'UNKNOWN_USER'.
  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? 'UNKNOWN_USER';

  // ─────────────────────────────────────────────────────────────────
  // 0. HARDWARE OWNERSHIP VERIFICATION — single source of truth
  // ─────────────────────────────────────────────────────────────────

  /// Returns true if the currently signed-in user is the original
  /// hardware owner of this physical device.
  ///
  /// On first call for a brand-new install, it registers the current
  /// user as the owner and returns true. Every subsequent call simply
  /// compares the stored UID against the authenticated UID.
  ///
  /// Used by SecurityLogsScreen and OperatorProfileScreen so the lock
  /// logic lives in exactly one place.
  Future<bool> verifyHardwareOwnership() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    final prefs = await SharedPreferences.getInstance();
    String? savedOwner = prefs.getString('hardware_owner_uid');

    if (savedOwner == null) {
      // First legitimate login — register this device to this user.
      await prefs.setString('hardware_owner_uid', uid);
      return true;
    }

    return uid == savedOwner;
  }

  // ─────────────────────────────────────────────────────────────────
  // 1. BREACH LOGGING — real telemetry auto-fetched
  // ─────────────────────────────────────────────────────────────────

  /// Logs a blocked breach attempt with real IP, geolocation, ISP,
  /// and hardware fingerprint resolved by [TelemetryService].
  ///
  /// [target] describes what the intruder tried to access, e.g.
  /// "VAULT FILE — fractal_7a3b" or "LOG PURGE BYPASS".
  Future<void> logBreachAttempt({required String target}) async {
    if (_currentUid == 'UNKNOWN_USER') return;

    try {
      final ThreatSnapshot snap = await _telemetry.captureSnapshot();

      await _db.collection('security_logs').add({
        'ownerId': _currentUid,
        'type': 'BREACH_ATTEMPT',       // 🔥 THE FIX: home_screen filters on this field
        'target': target,
        'ipAddress': snap.ipAddress,
        'isp': snap.isp,
        'location': snap.location,
        'deviceType': snap.deviceLabel,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'BLOCKED',
        'isThreat': true,               // kept for dashboard_screen._listenToSecurityLogs()
      });

      print('System: Breach logged for $_currentUid | IP: ${snap.ipAddress} | ${snap.location}');
    } catch (e) {
      print('Backend Error — Failed to log breach: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 2. AUTHORIZED ACCESS LOGGING — real telemetry auto-fetched
  // ─────────────────────────────────────────────────────────────────

  /// Logs a successful, authorized access event.
  ///
  /// [target] describes the accessed resource.
  /// [accessedBy] identifies the actor (user email or agent name, e.g. "Sentinel").
  ///
  /// IP, geolocation, ISP, and device info are now resolved automatically
  /// via [TelemetryService] — no more hardcoded placeholder strings.
  Future<void> logAuthorizedAccess({
    required String target,
    required String accessedBy,
  }) async {
    if (_currentUid == 'UNKNOWN_USER') return;

    try {
      final ThreatSnapshot snap = await _telemetry.captureSnapshot();

      await _db.collection('security_logs').add({
        'ownerId': _currentUid,
        'type': 'AUTHORIZED_ACCESS',    // symmetric with BREACH_ATTEMPT for future filtering
        'target': target,
        'ipAddress': snap.ipAddress,
        'isp': snap.isp,
        'location': snap.location,
        'deviceType': snap.deviceLabel,
        'accessedBy': accessedBy,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'GRANTED',
        'isThreat': false,
      });

      print('System: Authorized access logged for $_currentUid | ${snap.ipAddress}');
    } catch (e) {
      print('Backend Error — Failed to log authorized access: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 3. FETCH SECURITY LOGS — tenant-isolated real-time stream
  // ─────────────────────────────────────────────────────────────────

  /// Returns a real-time stream of this user's security logs, newest first.
  ///
  /// Sorted in Dart to avoid requiring a composite Firestore index
  /// (ownerId + timestamp).
  Stream<List<Map<String, dynamic>>> getSecurityLogs() {
    return _db
        .collection('security_logs')
        .where('ownerId', isEqualTo: _currentUid)
        .snapshots()
        .map((snapshot) {
      final logs = snapshot.docs.map((doc) {
        final data = doc.data();
        data['logId'] = doc.id;
        return data;
      }).toList();

      logs.sort((a, b) {
        final timeA = a['timestamp'] as Timestamp?;
        final timeB = b['timestamp'] as Timestamp?;
        if (timeA == null || timeB == null) return 0;
        return timeB.compareTo(timeA);
      });

      return logs;
    });
  }

  // ─────────────────────────────────────────────────────────────────
  // 4. LOG PURGE — hard-delete a single log document
  // ─────────────────────────────────────────────────────────────────

  /// Permanently deletes a security log by its Firestore document ID.
  ///
  /// The UI layer must call [verifyHardwareOwnership] before invoking
  /// this method — the service does not re-check ownership here.
  Future<void> deleteSecurityLog(String logId) async {
    try {
      await _db.collection('security_logs').doc(logId).delete();
      print('System: Security log $logId scrubbed.');
    } catch (e) {
      print('Backend Error — Failed to scrub log: $e');
    }
  }
}