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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
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
          child: StreamBuilder<QuerySnapshot>(
            // 📡 STREAM 1: Live vault files — already tenant-isolated
            stream: FirebaseFirestore.instance
                .collection('vault_files')
                .where('ownerId', isEqualTo: userId)
                .snapshots(),
            builder: (context, fileSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                // 📡 STREAM 2: Live security logs
                // ✅ FIX: Added ownerId filter so this works correctly
                // with the updated Firestore security rules. Previously
                // this fetched the entire collection and filtered in Dart,
                // which now silently returns 0 results because other users'
                // documents are blocked server-side.
                stream: FirebaseFirestore.instance
                    .collection('security_logs')
                    .where('ownerId', isEqualTo: userId)
                    .where('isThreat', isEqualTo: true)
                    .snapshots(),
                builder: (context, logSnapshot) {
                  if (fileSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF90CAFF)),
                    );
                  }

                  // 🧮 LIVE METRICS
                  final int totalFiles = fileSnapshot.data?.docs.length ?? 0;
                  final int activeShards = totalFiles * 5;

                  // ✅ FIX: Stream is already filtered to isThreat == true
                  // and ownerId == userId, so the count is just the doc count.
                  final int threatsBlocked = logSnapshot.data?.docs.length ?? 0;

                  // 🧮 DYNAMIC SECURITY SCORE — drops 2% per threat, floor 0
                  int score = 100 - (threatsBlocked * 2);
                  if (score < 0) score = 0;

                  // ✅ FIX: "BREACH DETECTED" now appears as soon as any
                  // threat exists, before the score degrades to WARNING.
                  String status = 'SECURE';
                  if (threatsBlocked > 0) status = 'BREACH DETECTED';
                  if (score < 90) status = 'WARNING';
                  if (score < 60) status = 'CRITICAL';

                  // ⏱️ LIVE RADAR PING TIME
                  final now = DateTime.now();
                  final lastScan =
                      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 50),

                        const Text(
                          'SYSTEM DIAGNOSTICS',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              letterSpacing: 2,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 30),

                        _buildHealthGauge(score, status, threatsBlocked),

                        const SizedBox(height: 40),

                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.95,
                          children: [
                            _buildStatCard('Total Files', '$totalFiles',
                                Icons.folder_zip, const Color(0xFFFFCA28)),
                            _buildStatCard('Active Shards', '$activeShards',
                                Icons.extension, const Color(0xFFB388FF)),
                            _buildStatCard('Threats Blocked', '$threatsBlocked',
                                Icons.gpp_bad, const Color(0xFFFF5252)),
                            _buildStatCard('Last Scan', lastScan, Icons.radar,
                                const Color(0xFFAED581)),
                          ],
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHealthGauge(int score, String status, int threatCount) {
    // Shield glows red when breached, blue when secure.
    final Color gaugeColor =
        threatCount > 0 ? Colors.redAccent : const Color(0xFF90CAFF);

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
                color: gaugeColor.withOpacity(0.2 * _pulseController.value),
                blurRadius: 30,
                spreadRadius: 10,
              ),
            ],
            border: Border.all(
                color: gaugeColor.withOpacity(0.5), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_rounded, color: gaugeColor, size: 68),
              const SizedBox(height: 8),
              Text(
                '$score%',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    height: 1.0),
              ),
              const SizedBox(height: 5),
              Text(
                status,
                style: TextStyle(
                    color: gaugeColor,
                    fontSize: status == 'BREACH DETECTED' ? 13 : 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color highlightColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: highlightColor.withOpacity(0.3), width: 1.5),
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
                Shadow(
                    color: highlightColor.withOpacity(0.5), blurRadius: 10)
              ],
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
    final List<IconData> doodleIcons = [
      Icons.monitor_heart,
      Icons.speed,
      Icons.memory,
      Icons.data_usage,
      Icons.bolt,
      Icons.health_and_safety,
    ];

    return IgnorePointer(
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF90CAFF), Color(0xFF0D2137)],
            stops: [0.1, 0.9],
          ).createShader(bounds);
        },
        blendMode: BlendMode.srcATop,
        child: Opacity(
          opacity: 0.15,
          child: GridView.builder(
            padding: const EdgeInsets.all(15),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 30,
              crossAxisSpacing: 30,
            ),
            itemCount: 100,
            itemBuilder: (context, index) {
              return Transform.rotate(
                angle: (index % 2 == 0) ? 0.2 : -0.2,
                child: Icon(
                  doodleIcons[index % doodleIcons.length],
                  size: 26,
                  color: Colors.white,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
