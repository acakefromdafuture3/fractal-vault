// Location: lib/screens/dashboard_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart'; 
import 'category_screen.dart'; 
import 'home_screen.dart';
import 'security_logs_screen.dart'; // 🔥 BRINGING THE 3RD TAB BACK!
import '../widgets/doodle_background.dart';
import '../services/vault_service.dart';
import '../widgets/shredder_engine.dart';
import '../services/cloud_dispatcher.dart';
import '../services/local_node_manager.dart';
import '../widgets/reconstruction_engine.dart';

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
      // 🔥 THE UPGRADE: Added allowMultiple: true
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'txt', 'jpg', 'png', 'doc', 'docx', // Original
          'mp4', 'mov', 'mkv', 'avi',                // 🔥 Unlocks Videos!
          'mp3', 'wav', 'm4a', 'aac'                 // 🔥 Unlocks Audios!
        ],
        allowMultiple: true, 
      );

      if (result == null || result.files.isEmpty) return; 

      setState(() => _isUploading = true);

      // 🔥 THE UPGRADE: Loop through EVERY selected file!
      for (var file in result.files) {
        if (file.path == null) continue; // Skip if something goes wrong with one file
        
        String filePath = file.path!; 
        String fileName = file.name;
        String extension = file.extension ?? fileName.split('.').last.toLowerCase();
        int fileSize = file.size;

        // ==========================================
        // 🧪 FRACTAL SHREDDER TEST ZONE (START)
        // ==========================================
        try {
          File physicalFile = File(filePath);
          Uint8List fileBytes = await physicalFile.readAsBytes();
          
          ShredderEngine shredder = ShredderEngine();
          List<Uint8List> myShards = shredder.sliceFile(fileBytes);
          
          // Use a simple, short ID for Appwrite compatibility
          String testFileId = "doc_${DateTime.now().millisecondsSinceEpoch}"; 

          // 🚀 1. FIRE SHARD 1 TO SUPABASE
          CloudDispatcher cloudDispatcher = CloudDispatcher();
          await cloudDispatcher.uploadToSupabase(
            fileId: testFileId, 
            shardBytes: myShards[0] 
          );

          // 🚀 2. FIRE SHARD 2 TO APPWRITE
          await cloudDispatcher.uploadToAppwrite(
            fileId: testFileId, 
            shardBytes: myShards[1] 
          );

          // 💾 3. BURY SHARD 5 IN THE HARDWARE
          LocalNodeManager localNode = LocalNodeManager();
          await localNode.securePhysicalKey(
            fileId: testFileId,
            shardBytes: myShards[4] 
          );
          // ==========================================
          // 🧬 PHASE 2: THE RECONSTRUCTION TEST
          // ==========================================
          print("⏳ Waiting 2 seconds before attempting reconstruction...");
          await Future.delayed(const Duration(seconds: 2));

          ReconstructionEngine reconstructor = ReconstructionEngine();
          
          // We are feeding it exactly 3 shards to prove the threshold works.
          // Shard 0 (Supabase), Shard 1 (Appwrite), and Shard 4 (Local Hardware)
          List<Uint8List> vaultShards = [
            myShards[0], 
            myShards[1], 
            myShards[4]  
          ];

          reconstructor.rebuildFile(vaultShards);

        } catch (e) {
          print("❌ ERROR: $e");
        }
        // ==========================================
        // 🧪 FRACTAL SHREDDER TEST ZONE (END)
        // ==========================================
       await VaultService().uploadFile(
          name: fileName,
          path: filePath,
          extension: extension,
          size: fileSize,
          isSecret: false, 
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${result.files.length} Files Sharded & Logged!"), 
          backgroundColor: Colors.green
        ));
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  String _mapExtensionToCategory(String ext) {
    if (['jpg', 'png', 'jpeg'].contains(ext.toLowerCase())) return 'image';
    if (['pdf', 'doc', 'docx'].contains(ext.toLowerCase())) return 'document';
    if (['txt','csv','md'].contains(ext.toLowerCase())) return 'text';
    if (['mp3', 'wav'].contains(ext.toLowerCase())) return 'audio';
    if (['mp4', 'mov'].contains(ext.toLowerCase())) return 'video';
    return 'document';
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