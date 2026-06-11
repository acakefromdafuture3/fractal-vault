// Location: lib/services/telemetry_service.dart
//
// 🛰️ TELEMETRY SERVICE — Real-time threat fingerprinting
// Captures IP address, geolocation, ISP, and hardware device info.
// Every network call is wrapped in try-catch with a timeout failsafe,
// so a VPN, firewall, or dead network never crashes the app.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

/// Encapsulates all real-time telemetry captured about the rogue device.
class ThreatSnapshot {
  final String ipAddress;
  final String city;
  final String country;
  final String isp;
  final String deviceLabel; // e.g. "iPhone 15 Pro" or "Pixel 7 (Android 14, SDK 34)"

  const ThreatSnapshot({
    required this.ipAddress,
    required this.city,
    required this.country,
    required this.isp,
    required this.deviceLabel,
  });

  /// Human-readable location string for the Firestore 'location' field.
  String get location {
    if (city == 'Unknown' && country == 'Unknown') return 'Origin Masked / Unknown';
    if (city == 'Unknown') return country;
    return '$city, $country';
  }
}

class TelemetryService {
  static const Duration _networkTimeout = Duration(seconds: 6);

  // ─────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────────

  /// Fetches the full threat snapshot: IP + geo + device info.
  /// Always resolves — falls back to "Unknown" on any failure.
  Future<ThreatSnapshot> captureSnapshot() async {
    // Run both lookups concurrently for speed.
    final results = await Future.wait([
      _fetchNetworkInfo(),
      _fetchDeviceLabel(),
    ]);

    final net = results[0] as _NetworkInfo;
    final deviceLabel = results[1] as String;

    return ThreatSnapshot(
      ipAddress: net.ip,
      city: net.city,
      country: net.country,
      isp: net.isp,
      deviceLabel: deviceLabel,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // NETWORK INFO  (ip-api.com — free, no key required, 45 req/min)
  // ─────────────────────────────────────────────────────────────────

  Future<_NetworkInfo> _fetchNetworkInfo() async {
    try {
      final uri = Uri.parse('http://ip-api.com/json/?fields=status,query,city,country,isp');

      final response = await http
          .get(uri)
          .timeout(_networkTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // ip-api returns {"status":"fail"} for private/loopback IPs (emulators).
        if (data['status'] == 'success') {
          return _NetworkInfo(
            ip: (data['query'] as String?)?.trim() ?? 'Unknown',
            city: (data['city'] as String?)?.trim() ?? 'Unknown',
            country: (data['country'] as String?)?.trim() ?? 'Unknown',
            isp: (data['isp'] as String?)?.trim() ?? 'Unknown',
          );
        }
      }
    } on SocketException {
      // No network connectivity.
    } on HttpException {
      // Bad HTTP response.
    } catch (_) {
      // Timeout or any unexpected error.
    }

    return const _NetworkInfo(
      ip: 'Unknown / Masked',
      city: 'Unknown',
      country: 'Unknown',
      isp: 'Unknown',
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // DEVICE INFO  (device_info_plus)
  // ─────────────────────────────────────────────────────────────────

  Future<String> _fetchDeviceLabel() async {
    try {
      final plugin = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        // e.g. "Pixel 7 Pro · Android 14 (SDK 34) · fingerprint: …"
        final brand = _capitalize(info.brand);
        final model = info.model;
        final sdk = info.version.sdkInt;
        final release = info.version.release;
        final fingerprint = info.fingerprint.isNotEmpty
            ? info.fingerprint.split('/').last // last segment is most readable
            : 'N/A';
        return '$brand $model · Android $release (SDK $sdk) · fp: $fingerprint';
      }

      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        // e.g. "iPhone 15 Pro · iOS 17.4 · UDID: ABC123…"
        final name = info.name;           // "Rik's iPhone"
        final model = info.utsname.machine; // "iPhone16,1"
        final sysVersion = info.systemVersion;
        final idVendor = info.identifierForVendor ?? 'N/A';
        return '$name ($model) · iOS $sysVersion · idfv: $idVendor';
      }

      // Fallback for desktop (macOS / Linux / Windows) — unlikely but safe.
      return Platform.operatingSystem.toUpperCase();
    } catch (_) {
      return Platform.operatingSystem.toUpperCase();
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

// ─────────────────────────────────────────────────────────────────
// PRIVATE VALUE OBJECT
// ─────────────────────────────────────────────────────────────────

class _NetworkInfo {
  final String ip;
  final String city;
  final String country;
  final String isp;

  const _NetworkInfo({
    required this.ip,
    required this.city,
    required this.country,
    required this.isp,
  });
}
