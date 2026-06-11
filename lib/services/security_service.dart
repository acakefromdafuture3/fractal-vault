// Location: lib/services/security_service.dart
//
// 🔒 SECURITY SERVICE — Fractal Vault threat logging backbone
// All breach and authorized-access events are written to Firestore
// under the authenticated user's ownerId, so each tenant only ever
// sees their own logs (tenant isolation).
//
// logBreachAttempt() now calls TelemetryService to resolve the real
// IP, geolocation, ISP, and hardware fingerprint before writing the
// Firestore document. logAuthorizedAccess() keeps explicit parameters
// so the call-site can supply context the telemetry API cannot know
// (e.g., the Sentinel agent that triggered the access).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'telemetry_service.dart';

class SecurityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TelemetryService _telemetry = TelemetryService();

  /// Safely returns the current user's UID, or 'UNKNOWN_USER'.
  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? 'UNKNOWN_USER';

  // ─────────────────────────────────────────────────────────────────
  // 1. BREACH LOGGING — real telemetry auto-fetched
  // ─────────────────────────────────────────────────────────────────

  /// Logs a blocked breach attempt.
  ///
  /// [target] describes what the intruder tried to access, e.g.
  /// "VAULT FILE — fractal_7a3b" or "SYSTEM LOGS PURGE".
  ///
  /// All network/IP/geo/device data is resolved automatically via
  /// [TelemetryService]. The call is fully async and never throws —
  /// any lookup failure falls back to "Unknown / Masked".
  Future<void> logBreachAttempt({required String target}) async {
    if (_currentUid == 'UNKNOWN_USER') return;

    try {
      // 🛰️ Capture real telemetry before writing to Firestore.
      // captureSnapshot() runs the IP lookup and device fingerprint
      // concurrently, with a 6-second timeout on each network call.
      final ThreatSnapshot snap = await _telemetry.captureSnapshot();

      await _db.collection('security_logs').add({
        'ownerId': _currentUid,
        'target': target,
        'ipAddress': snap.ipAddress,
        'isp': snap.isp,
        'location': snap.location,        // "Kolkata, India" or "Origin Masked / Unknown"
        'deviceType': snap.deviceLabel,   // "Pixel 7 Pro · Android 14 (SDK 34) · fp: …"
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'BLOCKED',
        'isThreat': true,
      });

      print('System: Breach logged for $_currentUid | IP: ${snap.ipAddress} | ${snap.location}');
    } catch (e) {
      print('Backend Error — Failed to log breach: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 2. AUTHORIZED ACCESS LOGGING — caller supplies context
  // ─────────────────────────────────────────────────────────────────

  /// Logs a successful, authorized access event.
  ///
  /// The caller explicitly supplies [ipAddress], [location], and
  /// [deviceType] because authorized access is typically initiated
  /// by the vault owner's known device — no extra lookup needed.
  /// [accessedBy] identifies the actor (user email or agent name).
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
        'ownerId': _currentUid,
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
      print('Backend Error — Failed to log authorized access: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // 3. FETCH SECURITY LOGS — tenant-isolated stream
  // ─────────────────────────────────────────────────────────────────

  /// Returns a real-time stream of this user's security logs, newest first.
  ///
  /// The [where('ownerId')] clause ensures tenant isolation: each user
  /// only receives their own documents even though all logs share the
  /// same top-level 'security_logs' collection.
  ///
  /// Sorting is done in Dart to avoid requiring a composite Firestore
  /// index (ownerId + timestamp).
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
        return timeB.compareTo(timeA); // newest first
      });

      return logs;
    });
  }

  // ─────────────────────────────────────────────────────────────────
  // 4. LOG PURGE — hard-delete a single log document
  // ─────────────────────────────────────────────────────────────────

  /// Permanently deletes a security log by its Firestore document ID.
  ///
  /// The UI layer is responsible for enforcing the hardware-lock guard
  /// before calling this method.
  Future<void> deleteSecurityLog(String logId) async {
    try {
      await _db.collection('security_logs').doc(logId).delete();
      print('System: Security log $logId scrubbed.');
    } catch (e) {
      print('Backend Error — Failed to scrub log: $e');
    }
  }
}
