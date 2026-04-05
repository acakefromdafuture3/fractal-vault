// Location: lib/screens/dashboard_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; 
import 'category_screen.dart'; 
import 'home_screen.dart';
import '../widgets/doodle_background.dart';
import '../services/vault_service.dart'; // 🔥 ADDED: Hooking into Ritankar's Engine
import 'security_logs_screen.dart'; // 🔥 Add this near your other imports

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentNavIndex = 0; 
  bool _isUploading = false; 

  Future<void> _pickAndLogMetadata(ColorScheme colors) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'jpg', 'png', 'doc', 'docx', 'mp4', 'mp3'], 
      );

      if (result == null) return; 

      setState(() => _isUploading = true);

      String filePath = result.files.single.path!; 
      String fileName = result.files.single.name;
      String extension = result.files.single.extension ?? 'unknown';
      int fileSize = result.files.single.size;

      // 🔌 THE FIX: Sending the file directly to Ritankar's Master Upload Portal!
      await VaultService().uploadFile(
        name: fileName,
        path: filePath,
        extension: extension,
        size: fileSize,
        isSecret: false, // 👈 Public Vault (Main Screen)
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("File Sharded & Logged!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    
    final List<Widget> pages = [
      const HomeScreen(),
      const CategoryScreen(),
      const SecurityLogsScreen(),
      _buildPlaceholderScreen("System Protocols", Icons.admin_panel_settings_outlined, colors, "settings"),
    ];

    return Scaffold(
      extendBody: true, 
      body: pages[_currentNavIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : () => _pickAndLogMetadata(colors), 
        backgroundColor: _isUploading ? Colors.grey : const Color(0xFF90CAFF), 
        child: _isUploading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF0D2137), strokeWidth: 2)) 
            : const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF0D2137), 
        shape: const CircularNotchedRectangle(), 
        notchMargin: 8,
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

  Widget _buildPlaceholderScreen(String title, IconData icon, ColorScheme colors, String type) {
    List<IconData> getDoodles() {
      if (title == "System Protocols") {
        return [Icons.settings, Icons.build, Icons.memory, Icons.tune, Icons.admin_panel_settings, Icons.developer_board];
      } else if (title == "Security Firewall") {
        return [Icons.security, Icons.lock, Icons.shield, Icons.vpn_key, Icons.verified_user];
      }
      return [Icons.code, Icons.data_object, Icons.terminal, Icons.bug_report];
    }

    return Stack(
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
        
        CodeDoodleBackground(icons: getDoodles()), 
        
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: const Color(0xFF90CAFF)),
              const SizedBox(height: 20),
              Text(
                title, 
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)
              ),
              const SizedBox(height: 10),
              const Text(
                "MODULE CURRENTLY OFFLINE", 
                style: TextStyle(color: Colors.white54, fontFamily: 'Courier', letterSpacing: 2)
              ),
            ],
          ),
        ),
      ],
    );
  }
}