// Location: lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import '../services/security_service.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../services/encryption_service.dart';
import '../services/cloud_dispatcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final SecurityService _securityService = SecurityService();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // 1. Set up the glowing pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    // We completely removed the database initialization from here!
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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

        // LAYER 3: UI Content wrapped in the LIVE STREAM
        SafeArea(
          child: StreamBuilder<Map<String, dynamic>>(
            stream: _securityService.getSystemStats(),
            builder: (context, snapshot) {
              // Show your custom loading spinner while connecting
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF90CAFF)));
              }

              // Extract the live data (or use safe defaults)
              final stats = snapshot.data ?? {};
              final int score = stats['securityScore'] ?? 0;
              final String status = score >= 90 ? "SECURE" : "WARNING"; // Auto-calculate status

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

                    // GLOWING HEALTH GAUGE (Passing the live score and status)
                    _buildHealthGauge(score, status),

                    const SizedBox(height: 40),

                    // COLOR-CODED DATA GRID (Passing live stats)
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.95, 
                      children: [
                        _buildStatCard("Total Files", '${stats['totalFiles'] ?? 0}', Icons.folder_zip, const Color(0xFFFFCA28)), 
                        _buildStatCard("Active Shards", '${stats['activeShards'] ?? 0}', Icons.extension, const Color(0xFFB388FF)), 
                        _buildStatCard("Threats Blocked", '${stats['threatsBlocked'] ?? 0}', Icons.gpp_bad, const Color(0xFFFF5252)), 
                        _buildStatCard("Last Scan", '${stats['lastScan'] ?? '--:--'}', Icons.radar, const Color(0xFFAED581)), 
                      ],
                    ),
                    const SizedBox(height: 100), 
                  ],
                ),
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