// Location: lib/screens/dashboard_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'package:open_filex/open_filex.dart';       

import 'home_screen.dart';
import 'category_screen.dart'; 
import 'security_logs_screen.dart'; 
import 'system_protocols_screen.dart'; 
import '../widgets/doodle_background.dart';

import '../services/vault_service.dart';
import '../services/encryption_service.dart';
import '../services/cloud_dispatcher.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentNavIndex = 0; 
  bool _isProcessing = false; // 🔥 Renamed to clarify it just locks the buttons now, no tiny spinner!

  Future<void> _viewSecureFile(Map<String, dynamic> fileData) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Fetching shards and decrypting..."), duration: Duration(seconds: 2))
    );

    try {
      final String fileId = fileData['docId'];
      final List<String> shards = List<String>.from(fileData['shards']);
      final String ivBase64 = fileData['iv'];
      final String extension = fileData['extension'];

      final cloud = CloudDispatcher();
      Uint8List? encryptedBytes = await cloud.downloadFromSupabase(fileId);

      if (encryptedBytes == null) throw Exception("Node 1 unreachable.");

      final crypto = EncryptionService();
      String recoveredKey = crypto.rebuildAesKey(shards);
      Uint8List plainBytes = crypto.decryptHeavyFile(encryptedBytes, recoveredKey, ivBase64);

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/view_$fileId.$extension');
      await tempFile.writeAsBytes(plainBytes);

      await OpenFilex.open(tempFile.path);

    } catch (e) {
      debugPrint("View Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

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
              leading: const Icon(Icons.upload_file, color: Colors.greenAccent, size: 28), 
              title: const Text("Secure Single File", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: const Text("Encrypt & shatter across 5 nodes", style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context); 
                _pickAndSecureFiles(colors, isMultiple: false); 
              },
            ),

            ListTile(
              leading: const Icon(Icons.library_add, color: Color(0xFF90CAFF), size: 28),
              title: const Text("Multiple Files (Bulk)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: const Text("Select multiple items at once", style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _pickAndSecureFiles(colors, isMultiple: true); 
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSecureFiles(ColorScheme colors, {required bool isMultiple}) async {
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

      setState(() => _isProcessing = true);

      // 🔥 1. SHOW THE ANIMATION FIRST
      showDialog(
        context: context,
        barrierDismissible: false, 
        builder: (context) => const ShardingAnimationDialog(),
      );

      // 🔥 2. THE MAGIC FIX: Give Flutter exactly 600 milliseconds to draw the animation
      // before we lock up the CPU with heavy encryption math!
      await Future.delayed(const Duration(milliseconds: 600));

      // 3. Now we can safely do the heavy lifting in the background
      for (var file in result.files) {
        if (file.path == null) continue; 
        
        String filePath = file.path!; 
        String fileName = file.name;
        String extension = file.extension ?? fileName.split('.').last.toLowerCase();

        final fileBytes = await File(filePath).readAsBytes();

        final engine = EncryptionService();
        final aesKey = engine.generateMasterAesKey();
        final encryptedData = engine.encryptHeavyFile(fileBytes, aesKey);
        final keyShards = engine.shredAesKey(aesKey);

        await VaultService().uploadEncryptedFile(
          name: fileName,
          extension: extension,
          encryptedBytes: encryptedData['encryptedBytes'],
          iv: encryptedData['iv'],
          shards: keyShards,
        );
      }

      if (mounted) {
        Navigator.pop(context); // Close the animation dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${result.files.length} File(s) Secured & Shattered!"), 
          backgroundColor: Colors.green
        ));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Make sure to close the dialog if an error happens
      debugPrint("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Encryption Error: $e"), 
          backgroundColor: Colors.redAccent
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
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
        onPressed: _isProcessing ? null : () => _showUploadOptions(colors),
        shape: const CircleBorder(), 
        elevation: 2,
        backgroundColor: _isProcessing ? Colors.grey : const Color(0xFF90CAFF), 
        // 🔥 REMOVED THE SPINNER: Now it just stays a static icon, letting the main screen animation do the talking!
        child: const Icon(Icons.add, size: 32, color: Color(0xFF0D2137)), 
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
} 

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
                  
                  final double fileOpacity = 1.0 - (progress * 3).clamp(0.0, 1.0); 
                  final double shardOpacity = progress < 0.1 ? (progress * 10) : (1.0 - progress);
                  final double distance = progress * 45.0; 

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      ...List.generate(5, (index) {
                        final double angle = (index * (360 / 5)) * (math.pi / 180);
                        final double dx = math.cos(angle) * distance;
                        final double dy = math.sin(angle) * distance;

                        return Transform.translate(
                          offset: Offset(dx, dy),
                          child: Opacity(
                            opacity: shardOpacity,
                            child: Transform.rotate(
                              angle: progress * math.pi * 3, 
                              child: const Icon(Icons.change_history, color: Color(0xFF90CAFF), size: 24), 
                            ),
                          ),
                        );
                      }),
                      
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