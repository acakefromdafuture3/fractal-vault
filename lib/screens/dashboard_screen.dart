// Location: lib/screens/dashboard_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart'; 

import 'home_screen.dart';
import 'category_screen.dart'; 
import 'security_logs_screen.dart'; 
import 'system_protocols_screen.dart'; 
import '../widgets/doodle_background.dart';

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
        allowedExtensions: ['pdf', 'txt', 'jpg', 'png', 'doc', 'docx'], 
        allowMultiple: isMultiple, 
      );

      if (result == null || result.files.isEmpty) return; 

      setState(() => _isUploading = true);

      for (var file in result.files) {
        if (file.path == null) continue; 
        
        String filePath = file.path!; 
        String fileName = file.name;
        String extension = file.extension ?? fileName.split('.').last.toLowerCase();
        int fileSize = file.size;

        await FirebaseFirestore.instance.collection('vault_files').add({
          'name': fileName,
          'type': _mapExtensionToCategory(extension),
          'extension': extension,
          'size': fileSize,
          'path': filePath, 
          'status': 'Secured',
          'isSecret': false, 
          'dateAdded': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${result.files.length} File(s) Sharded & Logged!"), 
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
      const SecurityLogsScreen(), // 🔥 Tab 3 is active!
      const SystemProtocolsScreen(), // 🔥 Tab 4 is active!
    ];

    return Scaffold(
      extendBody: true, 
      body: pages[_currentNavIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : () => _showUploadOptions(colors),
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
}