import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart'; 
import 'category_screen.dart'; 
import 'home_screen.dart';

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
        allowedExtensions: ['pdf', 'txt', 'jpg', 'png', 'doc', 'docx'], 
      );

      if (result == null) return; 

      setState(() => _isUploading = true);

      String filePath = result.files.single.path!; 
      String fileName = result.files.single.name;
      String extension = result.files.single.extension ?? 'unknown';
      int fileSize = result.files.single.size;

      await FirebaseFirestore.instance.collection('vault_files').add({
        'name': fileName,
        'type': _mapExtensionToCategory(extension),
        'extension': extension,
        'size': fileSize,
        'path': filePath, 
        'status': 'Secured', 
        'dateAdded': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text("File Sharded & Logged!"), backgroundColor: Colors.green)
      );
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
      _buildPlaceholderScreen("Security Firewall", Icons.security_rounded, colors, "security"),
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

  // 🔥 THIS WAS THE MISSING METHOD!
  Widget _buildPlaceholderScreen(String title, IconData mainIcon, ColorScheme colors, String type) {
    List<IconData> doodleIcons = [Icons.lock, Icons.fingerprint, Icons.vpn_key, Icons.policy, Icons.gpp_good];
    
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
        // Helper widget defined in CategoryScreen or globally
        const CategoryDoodleBackground(icons: [Icons.security, Icons.shield, Icons.lock]), 
        
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

// Defining this globally so both screens can use it
class CategoryDoodleBackground extends StatelessWidget {
  final List<IconData> icons;
  const CategoryDoodleBackground({super.key, required this.icons});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ShaderMask(
        shaderCallback: (Rect bounds) => const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF90CAFF), Color(0xFF0D2137)],
        ).createShader(bounds),
        blendMode: BlendMode.srcATop,
        child: Opacity(
          opacity: 0.1, 
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5),
            itemCount: 40,
            itemBuilder: (context, index) => Icon(icons[index % icons.length], size: 24, color: Colors.white),
          ),
        ),
      ),
    );
  }
}