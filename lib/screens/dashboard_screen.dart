// Location: lib/screens/dashboard_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:path_provider/path_provider.dart'; // 🔥 Needed for temporary decryption
import 'package:open_filex/open_filex.dart';       // 🔥 Needed to open the decrypted file

import 'home_screen.dart';
import 'category_screen.dart'; 
import 'security_logs_screen.dart'; 
import 'system_protocols_screen.dart'; 
import '../widgets/doodle_background.dart';

import '../services/vault_service.dart';
import '../services/vault_dispatcher.dart';
import '../services/encryption_service.dart';
import '../services/cloud_dispatcher.dart'; // 🔥 Needed to download the heavy file

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentNavIndex = 0; 
  bool _isUploading = false; 

  // 🔥 THE RECONSTRUCTION ENGINE
  // (Note: If your "Recent Activity" list is actually built inside category_screen.dart, 
  // you will need to copy this exact method into that file so the list tiles can call it!)
  Future<void> _viewSecureFile(Map<String, dynamic> fileData) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Fetching shards and decrypting..."), duration: Duration(seconds: 2))
    );

    try {
      final String fileId = fileData['docId'];
      final List<String> shards = List<String>.from(fileData['shards']);
      final String ivBase64 = fileData['iv'];
      final String extension = fileData['extension'];

      // 1. Download encrypted bytes from Node 1 (Supabase)
      final cloud = CloudDispatcher();
      Uint8List? encryptedBytes = await cloud.downloadFromSupabase(fileId);

      if (encryptedBytes == null) throw Exception("Node 1 unreachable.");

      // 2. Rebuild Key & Decrypt
      final crypto = EncryptionService();
      String recoveredKey = crypto.rebuildAesKey(shards);
      Uint8List plainBytes = crypto.decryptHeavyFile(encryptedBytes, recoveredKey, ivBase64);

      // 3. Save to Temp Cache
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/view_$fileId.$extension');
      await tempFile.writeAsBytes(plainBytes);

      // 4. Open it natively!
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
            
            // 🛡️ SECURE SINGLE UPLOAD
            ListTile(
              // 🔥 CHANGED: Swapped Icons.security for Icons.upload_file
              leading: const Icon(Icons.upload_file, color: Colors.greenAccent, size: 28), 
              title: const Text("Secure Single File", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: const Text("Encrypt & shatter across 5 nodes", style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () async {
                Navigator.pop(context); 
                setState(() => _isUploading = true); 
                
                // Triggers the Centralized Vault Dispatcher
                await VaultDispatcher.initiateSecureUpload(context); 
                
                if (mounted) setState(() => _isUploading = false);
              },
            ),

            // 📦 MULTIPLE FILES (BULK UPLOAD)
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

      for (var file in result.files) {
        if (file.path == null) continue; 
        
        String filePath = file.path!; 
        String fileName = file.name;
        String extension = file.extension ?? fileName.split('.').last.toLowerCase();

        // 1. Read the massive file into memory
        final fileBytes = await File(filePath).readAsBytes();

        // 2. Execute Cryptographic Pipeline
        final engine = EncryptionService();
        final aesKey = engine.generateMasterAesKey();
        final encryptedData = engine.encryptHeavyFile(fileBytes, aesKey);
        final keyShards = engine.shredAesKey(aesKey);

        // 3. Send to the VaultService (which automatically triggers your 5 nodes)
        await VaultService().uploadEncryptedFile(
          name: fileName,
          extension: extension,
          encryptedBytes: encryptedData['encryptedBytes'],
          iv: encryptedData['iv'],
          shards: keyShards,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${result.files.length} File(s) Secured & Shattered!"), 
          backgroundColor: Colors.green
        ));
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Encryption Error: $e"), 
          backgroundColor: Colors.redAccent
        ));
      }
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
              style: TextStyle(
                color: color, 
                fontSize: 10, 
                fontWeight: FontWeight.bold, 
                letterSpacing: 1.0, 
              )
            ),
          ],
        ),
      ),
    );
  }
}