// Location: lib/services/security_service.dart

class SecurityService {
  
  // 1. Data for the Home "Health Overview" Screen
  Future<Map<String, dynamic>> getVaultHealth() async {
    // Simulating a system scan delay
    await Future.delayed(const Duration(milliseconds: 600));
    
    return {
      "status": "Secure",
      "score": 98,
      "lastScan": "2026-04-02 19:30",
      "totalFiles": 14,
      "activeFragments": 56, // 14 files split into 4 shards each!
      "threatsBlocked": 2
    };
  }

  // 2. Data for the Security Logs Timeline
  Future<List<Map<String, String>>> getAccessLogs() async {
    // Simulating database fetch delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    return [
      {
        "event": "Login Success", 
        "ip": "192.168.1.45 (Local)", 
        "status": "success",
        "time": "Today, 19:05"
      },
      {
        "event": "File Shard Sync: Node 3", 
        "ip": "Internal Network", 
        "status": "info",
        "time": "Today, 18:45"
      },
      {
        "event": "Unauthorized Login Attempt", 
        "ip": "103.44.12.9 (Unknown)", 
        "status": "warning", // Tista can make the timeline dot RED for this!
        "time": "Today, 04:20"
      },
      {
        "event": "Fragment Reassembly: Aadhar_Card.pdf", 
        "ip": "192.168.1.45 (Local)", 
        "status": "success",
        "time": "Yesterday, 21:15"
      },
    ];
  }
}