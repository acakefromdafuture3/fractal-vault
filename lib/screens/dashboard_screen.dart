// Location: lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'category_screen.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentNavIndex = 0; // Starts on Home (0)

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // THE MASTER LIST OF PAGES
    final List<Widget> pages = [
      _buildPlaceholderScreen("Biometric Health", Icons.health_and_safety_outlined, colors, "home"),
      const CategoryScreen(), 
      _buildPlaceholderScreen("Security Firewall", Icons.security_rounded, colors, "security"),
      _buildPlaceholderScreen("System Protocols", Icons.admin_panel_settings_outlined, colors, "settings"),
    ];

    return Scaffold(
      extendBody: true, 
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Fractal Vault", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
        centerTitle: true,
      ),
      
      body: pages[_currentNavIndex],

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar(); 
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: const Text("Initializing Neural Encryption..."), 
               backgroundColor: colors.primary,
               behavior: SnackBarBehavior.floating,
               margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
             )
          );
        },
        backgroundColor: const Color(0xFF90CAFF), 
        foregroundColor: const Color(0xFF0D2137), 
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF0D2137), 
        shape: const CircularNotchedRectangle(), 
        notchMargin: 8,
        elevation: 0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavIcon(0, Icons.grid_view_rounded),
              _buildNavIcon(1, Icons.folder_special),
              const SizedBox(width: 40), 
              _buildNavIcon(2, Icons.shield_outlined),
              _buildNavIcon(3, Icons.settings_outlined),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(int index, IconData icon) {
    final isSelected = _currentNavIndex == index;
    return IconButton(
      icon: Icon(icon, color: isSelected ? const Color(0xFF90CAFF) : Colors.white.withOpacity(0.4), size: 28),
      onPressed: () => setState(() => _currentNavIndex = index),
    );
  }

  Widget _buildPlaceholderScreen(String title, IconData mainIcon, ColorScheme colors, String type) {
    List<IconData> doodleIcons = [];
    
    // Switch the background patterns based on the screen type
    if (type == "home") {
      doodleIcons = [Icons.favorite, Icons.monitor_heart, Icons.speed, Icons.query_stats, Icons.bolt, Icons.psychology];
    } else if (type == "security") {
      doodleIcons = [Icons.lock, Icons.fingerprint, Icons.vpn_key, Icons.policy, Icons.gpp_good, Icons.visibility_off];
    } else {
      doodleIcons = [Icons.tune, Icons.construction, Icons.memory, Icons.router, Icons.developer_board, Icons.data_usage];
    }
    
    return Stack(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [colors.primary, Colors.white], stops: const [0.2, 0.8],
            ),
          ),
        ),
        CodeDoodleBackground(icons: doodleIcons),
        
        SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(mainIcon, size: 80, color: const Color(0xFF90CAFF)),
                ),
                const SizedBox(height: 24),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 10),
                Text(
                  "SECURE PROTOCOL ACTIVE",
                  style: TextStyle(color: const Color(0xFF90CAFF).withOpacity(0.7), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}