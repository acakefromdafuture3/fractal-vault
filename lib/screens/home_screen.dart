// Location: lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // 1. Set up the glowing pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Stack(
      children: [
        // LAYER 1: Background Gradient
        Container(
          height: double.infinity,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.primary, Colors.white],
              stops: const [0.2, 0.8],
            ),
          ),
        ),

        // LAYER 2: High-Tech Doodles
        const HomeDoodleBackground(),

        // LAYER 3: UI Content wrapped in LIVE FIREBASE STREAMS
        SafeArea(
          // 📡 STREAM 1: Fetch the live Vault Files
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('vault_files').where('ownerId', isEqualTo: userId).snapshots(),
            builder: (context, fileSnapshot) {
              
              // 📡 STREAM 2: Fetch the live Security Logs
              return StreamBuilder<QuerySnapshot>(
                // We fetch all logs and filter in memory to avoid needing to build another Firebase Index
                stream: FirebaseFirestore.instance.collection('security_logs').snapshots(),
                builder: (context, logSnapshot) {

                  if (fileSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFF90CAFF)));
                  }

                  // 🧮 CALCULATE LIVE METRICS
                  final int totalFiles = fileSnapshot.data?.docs.length ?? 0;
                  final int activeShards = totalFiles * 5; // The Fractal Math!

                  int threatsBlocked = 0;
                  if (logSnapshot.hasData) {
                    final logs = logSnapshot.data!.docs;
                    for (var doc in logs) {
                      final data = doc.data() as Map<String, dynamic>;
                      // 💡 FIXED: Only increment if it's an actual threat!
  bool isThisUser = data['ownerId'] == userId || data['userId'] == userId;
  bool isActualThreat = data['isThreat'] == true; 

  if (isThisUser && isActualThreat) {
    threatsBlocked++;
  }
                    }
                  }

                  // 🧮 DYNAMIC SECURITY SCORE
                  int score = 100 - (threatsBlocked * 2); // Drops by 2% per threat
                  if (score < 0) score = 0;
                  
                  String status = "SECURE";
                  if (score < 90) status = "WARNING";
                  if (score < 60) status = "CRITICAL";

                  // ⏱️ LIVE RADAR PING TIME
                  final now = DateTime.now();
                  final lastScan = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 50), 
                        
                        // HEADER
                        const Text(
                          "SYSTEM DIAGNOSTICS",
                          style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 30),

                        // GLOWING HEALTH GAUGE
                        _buildHealthGauge(score, status),

                        const SizedBox(height: 40),

                        // COLOR-CODED DATA GRID
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.95, 
                          children: [
                            _buildStatCard("Total Files", '$totalFiles', Icons.folder_zip, const Color(0xFFFFCA28)), 
                            _buildStatCard("Active Shards", '$activeShards', Icons.extension, const Color(0xFFB388FF)), 
                            _buildStatCard("Threats Blocked", '$threatsBlocked', Icons.gpp_bad, const Color(0xFFFF5252)), 
                            _buildStatCard("Last Scan", lastScan, Icons.radar, const Color(0xFFAED581)), 
                          ],
                        ),
                        const SizedBox(height: 100), 
                      ],
                    ),
                  );
                }
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHealthGauge(int score, String status) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.05),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF90CAFF).withOpacity(0.2 * _pulseController.value),
                blurRadius: 30,
                spreadRadius: 10,
              )
            ],
            border: Border.all(color: const Color(0xFF90CAFF).withOpacity(0.5), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_rounded, color: Color(0xFF90CAFF), size: 68),
              const SizedBox(height: 8),
              Text(
                "$score%",
                style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, height: 1.0),
              ),
              const SizedBox(height: 5),
              Text(
                status,
                style: const TextStyle(color: Color(0xFF90CAFF), fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color highlightColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: highlightColor.withOpacity(0.3), width: 1.5), 
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: highlightColor, size: 28),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: highlightColor, 
              fontSize: 28,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(color: highlightColor.withOpacity(0.5), blurRadius: 10) 
              ]
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title.toUpperCase(), 
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: highlightColor, 
              fontSize: 12, 
              fontWeight: FontWeight.bold, 
              letterSpacing: 1.0, 
            ),
          ),
        ],
      ),
    );
  }
}

class HomeDoodleBackground extends StatelessWidget {
  const HomeDoodleBackground({super.key});

  @override
  Widget build(BuildContext context) {
    List<IconData> doodleIcons = [Icons.monitor_heart, Icons.speed, Icons.memory, Icons.data_usage, Icons.bolt, Icons.health_and_safety];

    return IgnorePointer(
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF90CAFF), Color(0xFF0D2137)], stops: [0.1, 0.9],
          ).createShader(bounds);
        },
        blendMode: BlendMode.srcATop,
        child: Opacity(
          opacity: 0.15, 
          child: GridView.builder(
            padding: const EdgeInsets.all(15),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5, mainAxisSpacing: 30, crossAxisSpacing: 30,
            ),
            itemCount: 100,
            itemBuilder: (context, index) {
              return Transform.rotate(
                angle: (index % 2 == 0) ? 0.2 : -0.2,
                child: Icon(doodleIcons[index % doodleIcons.length], size: 26, color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}