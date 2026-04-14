// Location: lib/screens/security_logs_screen.dart

import 'dart:io'; // 🔥 NEEDED FOR DEVICE OS DETECTION
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 

import '../services/security_service.dart'; 
import '../widgets/doodle_background.dart';

class SecurityLogsScreen extends StatefulWidget {
  const SecurityLogsScreen({super.key});

  @override
  State<SecurityLogsScreen> createState() => _SecurityLogsScreenState();
}

class _SecurityLogsScreenState extends State<SecurityLogsScreen> {
  final SecurityService _securityService = SecurityService();
  final user = FirebaseAuth.instance.currentUser;
  
  String _hardwareOwnerUid = "";

  @override
  void initState() {
    super.initState();
    _loadHardwareLock();
  }

  Future<void> _loadHardwareLock() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedOwner = prefs.getString('hardware_owner_uid');
    
    if (savedOwner == null) {
      savedOwner = user?.uid ?? "UNKNOWN";
      await prefs.setString('hardware_owner_uid', savedOwner);
    }
    
    setState(() {
      _hardwareOwnerUid = savedOwner!;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Stack(
        children: [
          Container(
            height: double.infinity, width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [colors.primary, Colors.white], stops: const [0.2, 0.8],
              ),
            ),
          ),
          
          const CodeDoodleBackground(
            icons: [Icons.security, Icons.lock, Icons.shield, Icons.vpn_key, Icons.verified_user],
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "ACCESS AUDIT",
                    style: TextStyle(color: Color(0xFF90CAFF), fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                  ),
                ),
                
                const SizedBox(height: 20),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D2137),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF90CAFF).withOpacity(0.3)),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: const Color(0xFF90CAFF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF90CAFF), width: 1),
                    ),
                    labelColor: const Color(0xFF90CAFF),
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: const [
                      Tab(text: "AUTHORIZED"),
                      Tab(text: "THREATS"),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _securityService.getSecurityLogs(), 
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF90CAFF)));
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text("SYSTEM ERROR: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                      }
                      
                      final allLogs = snapshot.data ?? [];
                      
                      final authorizedLogs = allLogs.where((log) => log['status'] == 'GRANTED').toList();
                      final threatLogs = allLogs.where((log) => log['status'] == 'BLOCKED').toList();
                      
                      return TabBarView(
                        children: [
                          _buildLogList(authorizedLogs, isThreat: false),
                          _buildLogList(threatLogs, isThreat: true),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList(List<Map<String, dynamic>> logs, {required bool isThreat}) {
    if (logs.isEmpty) {
      return Center(
        child: Text(
          isThreat ? "NO THREATS DETECTED." : "NO AUTHORIZED ACCESS LOGS.", 
          style: const TextStyle(color: Colors.white54, letterSpacing: 2, fontFamily: 'Courier')
        )
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 100),
      itemCount: logs.length,
      itemBuilder: (context, index) => _buildLogCard(logs[index], isThreat: isThreat),
    );
  }

  // 🔥 DYNAMIC CARD: Now recognizes ALL Hardware Spoofing traps!
  Widget _buildLogCard(Map<String, dynamic> log, {required bool isThreat}) {
    String logTime = "UNKNOWN TIME";
    if (log['timestamp'] != null && log['timestamp'] is Timestamp) {
      logTime = (log['timestamp'] as Timestamp).toDate().toString().split('.')[0];
    }

    final String targetInfo = (log['target'] ?? "Unknown").toString().toUpperCase();
    
    // 🔥 EXPANDED RADAR: Now catches Profile, Password, and Purge hacks!
    final bool isHardwareSpoofing = isThreat && (
      targetInfo.contains("PROFILE") || 
      targetInfo.contains("DOSSIER") || 
      targetInfo.contains("AVATAR") ||
      targetInfo.contains("PASSWORD") || 
      targetInfo.contains("FALLBACK") ||
      targetInfo.contains("PURGE")
    );

    Color themeColor = isThreat ? Colors.redAccent : Colors.greenAccent;
    IconData themeIcon = isThreat ? Icons.warning_amber_rounded : Icons.check_circle_outline;

    // 🔥 Apply the deep orange hardware lock theme
    if (isHardwareSpoofing) {
      themeColor = Colors.deepOrangeAccent; 
      themeIcon = Icons.fingerprint; 
    }

    final bool isIntruder = user?.uid != _hardwareOwnerUid && _hardwareOwnerUid.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.05), 
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: themeColor.withOpacity(isHardwareSpoofing ? 0.8 : 0.3), width: isHardwareSpoofing ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(themeIcon, color: themeColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    log['status'] ?? (isThreat ? "BLOCKED" : "GRANTED"),
                    style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontFamily: 'Courier'),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    logTime,
                    style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'Courier'),
                  ),
                  const SizedBox(width: 10),
                  
                  // 🔥 THE DOUBLE-TRAP SECURED DELETE BUTTON
                  GestureDetector(
                    onTap: () {
                      if (isIntruder) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("🛑 ACCESS DENIED: Log scrubbing restricted to original hardware."),
                            backgroundColor: Colors.redAccent,
                            duration: Duration(seconds: 3),
                          ),
                        );
                        
                        _securityService.logBreachAttempt(
                          target: "SYSTEM LOGS PURGE", 
                          ipAddress: "DETECTING...", 
                          location: "Hardware Mismatch",
                          deviceType: Platform.operatingSystem, 
                        );

                      } else {
                        if (log['logId'] != null) {
                           _securityService.deleteSecurityLog(log['logId']);
                        }
                      }
                    },
                    child: Icon(
                      isIntruder ? Icons.lock_outline : Icons.delete_outline, 
                      color: isIntruder ? Colors.redAccent : Colors.white38, 
                      size: 20
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(color: Colors.white10, thickness: 1),
          ),
          
          // 🔥 The critical warning text for hardware spoofing!
          if (isHardwareSpoofing) 
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text("🚨 HARDWARE SPOOFING DETECTED", style: TextStyle(color: themeColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
            
          _buildLogDetail("TARGET", targetInfo),
          _buildLogDetail("IP ADDRESS", log['ipAddress'] ?? "0.0.0.0"),
          _buildLogDetail("LOCATION", log['location'] ?? "Unknown Origin"),
          _buildLogDetail("DEVICE", log['deviceType'] ?? "Unidentified"),
          if (!isThreat && log['accessedBy'] != null)
            _buildLogDetail("USER", log['accessedBy']),
        ],
      ),
    );
  }

  Widget _buildLogDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              "$label:",
              style: TextStyle(color: const Color(0xFF90CAFF).withOpacity(0.7), fontSize: 11, fontFamily: 'Courier', fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Courier'),
            ),
          ),
        ],
      ),
    );
  }
}