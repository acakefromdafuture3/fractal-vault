// Location: lib/screens/security_logs_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🔥 MAKE SURE THIS PATH MATCHES WHERE YOUR SERVICE IS SAVED!
import '../services/security_service.dart'; 
import '../widgets/doodle_background.dart';

class SecurityLogsScreen extends StatefulWidget {
  const SecurityLogsScreen({super.key});

  @override
  State<SecurityLogsScreen> createState() => _SecurityLogsScreenState();
}

class _SecurityLogsScreenState extends State<SecurityLogsScreen> {
  final SecurityService _securityService = SecurityService();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // 🔥 Added DefaultTabController for the swipeable lists!
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

                // 🔥 THE TACTICAL TAB BAR
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
                
                // LIVE LOG STREAM
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
                      
                      // 🔥 SPLIT THE DATA INTO TWO LISTS
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

  // 🔥 Helper to build the list
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

  // 🔥 DYNAMIC CARD: Turns Red for Threats, Green for Authorized!
  Widget _buildLogCard(Map<String, dynamic> log, {required bool isThreat}) {
    String logTime = "UNKNOWN TIME";
    if (log['timestamp'] != null && log['timestamp'] is Timestamp) {
      logTime = (log['timestamp'] as Timestamp).toDate().toString().split('.')[0];
    }

    final Color themeColor = isThreat ? Colors.redAccent : Colors.greenAccent;
    final IconData themeIcon = isThreat ? Icons.warning_amber_rounded : Icons.check_circle_outline;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.05), 
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: themeColor.withOpacity(0.3), width: 1),
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
              Text(
                logTime,
                style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'Courier'),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(color: Colors.white10, thickness: 1),
          ),
          _buildLogDetail("TARGET", log['target'] ?? "Unknown"),
          _buildLogDetail("IP ADDRESS", log['ipAddress'] ?? "0.0.0.0"),
          _buildLogDetail("LOCATION", log['location'] ?? "Unknown Origin"),
          _buildLogDetail("DEVICE", log['deviceType'] ?? "Unidentified"),
          if (!isThreat && log['accessedBy'] != null) // Extra info for authorized users
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