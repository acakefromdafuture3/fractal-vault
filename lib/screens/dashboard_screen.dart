// Location: lib/screens/dashboard_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart'; 

import 'home_screen.dart';
import 'category_screen.dart'; 
import 'security_logs_screen.dart'; 
import 'system_protocols_screen.dart'; 
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

  void _showUploadOptions(ColorScheme colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D2137),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.insert_drive_file, color: Color(0xFF90CAFF), size: 28),
              title: const Text("Single File (Fast)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: const Text("One-tap quick upload", style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _pickAndLogMetadata(colors, isMultiple: false); 
              },
            ),
            ListTile(
              leading: const Icon(Icons.library_add, color: Color(0xFF90CAFF), size: 28),
              title: const Text("Multiple Files (Bulk)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: const Text("Select multiple items at once", style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _pickAndLogMetadata(colors, isMultiple: true); 
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndLogMetadata(ColorScheme colors, {required bool isMultiple}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
        'pdf', 'txt', 'jpg', 'png', 'doc', 'docx', 
        'mp4', 'mov', 'mkv', 'avi',                
        'mp3', 'wav', 'm4a', 'aac'                 
      ],
      allowMultiple: isMultiple,
      );

      if (result == null || result.files.isEmpty) return; 

      setState(() => _isUploading = true);

      // 🔥 Triggers the Shard Explosion animation
      showDialog(
        context: context,
        barrierDismissible: false, 
        builder: (context) => const ShardingAnimationDialog(),
      );

      for (var file in result.files) {
        if (file.path == null) continue; 
        
        String filePath = file.path!; 
        String fileName = file.name;
        String extension = file.extension ?? fileName.split('.').last.toLowerCase();
        int fileSize = file.size;

        try {
          File physicalFile = File(filePath);
          Uint8List fileBytes = await physicalFile.readAsBytes();
          
          ShredderEngine shredder = ShredderEngine();
          List<Uint8List> myShards = shredder.sliceFile(fileBytes);
          
          String testFileId = "doc_${DateTime.now().millisecondsSinceEpoch}"; 

          CloudDispatcher cloudDispatcher = CloudDispatcher();
          LocalNodeManager localNode = LocalNodeManager();

          await cloudDispatcher.uploadToSupabase(fileId: testFileId, shardBytes: myShards[0]);
          await cloudDispatcher.uploadToAppwrite(fileId: testFileId, shardBytes: myShards[1]);
          await cloudDispatcher.uploadToCloudinary(fileId: testFileId, shardBytes: myShards[2]);
          await cloudDispatcher.uploadToImageKit(fileId: testFileId, shardBytes: myShards[3]);
          await localNode.securePhysicalKey(fileId: testFileId, shardBytes: myShards[4]);

          print("⏳ Waiting 2 seconds before attempting reconstruction...");
          await Future.delayed(const Duration(seconds: 2));

          ReconstructionEngine reconstructor = ReconstructionEngine();
          List<Uint8List> vaultShards = [myShards[0], myShards[2], myShards[4]];
          reconstructor.rebuildFile(vaultShards);

        } catch (e) {
          print("❌ ERROR: $e");
        }
        
       await VaultService().uploadFile(
         name: fileName,
         path: filePath,
         extension: extension,
         size: fileSize,
         isSecret: false, 
       );
      }

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${result.files.length} File(s) Sharded & Logged!"), 
          backgroundColor: Colors.green
        ));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); 
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
      const SystemProtocolsScreen(), 
    ];

    return Scaffold(
      extendBody: true, 
      backgroundColor: Colors.transparent, 
      body: pages[_currentNavIndex],
      
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : () => _showUploadOptions(colors),
        shape: const CircleBorder(), 
        elevation: 2,
        backgroundColor: _isUploading ? Colors.grey : const Color(0xFF90CAFF), 
        child: _isUploading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF0D2137), strokeWidth: 2)) 
            : const Icon(Icons.add, size: 32, color: Color(0xFF0D2137)), 
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF0D2137), 
        surfaceTintColor: Colors.transparent, 
        clipBehavior: Clip.antiAlias,         
        shape: const CircularNotchedRectangle(), 
        notchMargin: 8,
        child: SizedBox(
          height: 70, 
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavIcon(0, Icons.grid_view_rounded, "CORE"),
              _buildNavIcon(1, Icons.folder_special, "VAULT"),
              const SizedBox(width: 40), 
              _buildNavIcon(2, Icons.shield_outlined, "RADAR"),
              _buildNavIcon(3, Icons.settings_outlined, "SYSTEM"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(int index, IconData icon, String label) {
    final isSelected = _currentNavIndex == index;
    final color = isSelected ? const Color(0xFF90CAFF) : Colors.white.withOpacity(0.4);
    
    return InkWell(
      onTap: () => setState(() => _currentNavIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label, 
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)
            ),
          ],
        ),
      ),
    );
  }
} // 🔥 Notice how the DashboardScreen state safely ends here!

// =====================================================================
// 🔥 THE PURE SHARDING ANIMATION (CINEMATIC SLOW-MOTION)
// =====================================================================

class ShardingAnimationDialog extends StatefulWidget {
  const ShardingAnimationDialog({super.key});

  @override
  State<ShardingAnimationDialog> createState() => _ShardingAnimationDialogState();
}

class _ShardingAnimationDialogState extends State<ShardingAnimationDialog> with SingleTickerProviderStateMixin {
  late AnimationController _shardController;
  late Animation<double> _explodeProgress;
  String _statusText = "INITIALIZING SHREDDER...";
  
  final List<String> _steps = [
    "ANALYZING FILE...",
    "SHATTERING INTO 5 PIECES...",
    "ENCRYPTING PAYLOADS...",
    "DISPATCHING SHARDS..."
  ];

  @override
  void initState() {
    super.initState();
    _shardController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3500))..repeat();
    _explodeProgress = CurvedAnimation(parent: _shardController, curve: Curves.easeOutCubic);
    
    _cycleText();
  }

  void _cycleText() async {
    int index = 0;
    while (mounted) {
      setState(() => _statusText = _steps[index]);
      index = (index + 1) % _steps.length; 
      await Future.delayed(const Duration(milliseconds: 1500));
    }
  }

  @override
  void dispose() {
    _shardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, 
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1526).withOpacity(0.95), 
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF90CAFF), width: 1.5),
          boxShadow: [BoxShadow(color: const Color(0xFF90CAFF).withOpacity(0.4), blurRadius: 30, spreadRadius: 5)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            
            // 🔥 THE EXPLODING FILE ANIMATION
            SizedBox(
              height: 100,
              width: 100,
              child: AnimatedBuilder(
                animation: _shardController,
                builder: (context, child) {
                  final double progress = _explodeProgress.value;
                  
                  // The solid file vanishes smoothly
                  final double fileOpacity = 1.0 - (progress * 3).clamp(0.0, 1.0); 
                  
                  // The shards fade in fast, then fade out slowly as they fly away
                  final double shardOpacity = progress < 0.1 ? (progress * 10) : (1.0 - progress);
                  
                  // The shards travel exactly 45 pixels outward
                  final double distance = progress * 45.0; 

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // 1. The 5 Flying Shards!
                      ...List.generate(5, (index) {
                        final double angle = (index * (360 / 5)) * (math.pi / 180);
                        final double dx = math.cos(angle) * distance;
                        final double dy = math.sin(angle) * distance;

                        return Transform.translate(
                          offset: Offset(dx, dy),
                          child: Opacity(
                            opacity: shardOpacity,
                            child: Transform.rotate(
                              angle: progress * math.pi * 3, // Smooth, slow spinning
                              child: const Icon(Icons.change_history, color: Color(0xFF90CAFF), size: 24), 
                            ),
                          ),
                        );
                      }),
                      
                      // 2. The Main File (shrinks and fades)
                      Transform.scale(
                        scale: 1.0 - (progress * 0.4), 
                        child: Opacity(
                          opacity: fileOpacity,
                          child: const Icon(Icons.insert_drive_file, color: Colors.white, size: 50),
                        ),
                      ),
                    ],
                  );
                }
              ),
            ),
            
            const SizedBox(height: 15),
            const Text("FRACTAL SHARDING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2.0, fontSize: 16)),
            const SizedBox(height: 15),
            Text(_statusText, style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 25),
            ClipRRect(borderRadius: BorderRadius.circular(10), child: const LinearProgressIndicator(backgroundColor: Colors.white10, color: Color(0xFF90CAFF), minHeight: 4)),
          ],
        ),
      ),
    );
  }
}