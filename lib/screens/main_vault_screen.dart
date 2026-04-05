import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io'; 
import 'package:open_filex/open_filex.dart';
// 🔥 FIXED PATHS: Added ../services/ to tell Flutter where they actually live
import '../services/vault_service.dart'; 
import 'secret_vault_screen.dart'; 

// IMPORTANT: Make sure you actually created a file named vault_setup_wizard.dart in your screens folder!
import 'vault_setup_wizard.dart';
class MainVaultScreen extends StatefulWidget {
  const MainVaultScreen({Key? key}) : super(key: key);

  @override
  _MainVaultScreenState createState() => _MainVaultScreenState();
}

class _MainVaultScreenState extends State<MainVaultScreen> {
  final VaultService _vaultService = VaultService();
  
  // Settings for the Secret Vault trigger
  String _vaultLocation = '';
  bool _vaultIsHidden = false;
  String _vaultTrigger = '';

  @override
  void initState() {
    super.initState();
    _loadSecretVaultSettings();
  }

  // We load the settings so we know IF we should show the secret trigger here
  Future<void> _loadSecretVaultSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vaultLocation = prefs.getString('vaultLocation') ?? '';
      _vaultIsHidden = prefs.getBool('vaultIsHidden') ?? false;
      _vaultTrigger = prefs.getString('vaultTrigger') ?? '';
    });
  }

  // This refreshes the settings when you come back from the Setup Wizard
  Future<void> _openSetupWizard() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) =>VaultSetupWizard()),
    );
    _loadSecretVaultSettings(); // Reload settings in case they changed them!
  }

  void _openSecretVault() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SecretVaultScreen()),
    );
  }
  // 🔥 Opens the file when you tap it in the vault!
  Future<void> _openSecretFile(Map<String, dynamic> fileData) async {
    if (fileData['path'] != null) {
      try {
        File physicalFile = File(fileData['path']);
        if (!await physicalFile.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("ERROR: File missing from local storage."), 
              backgroundColor: Colors.redAccent
            ));
          }
          return; 
        }
        // Uses OpenFilex to launch the photo/video in your phone's native viewer
        await OpenFilex.open(fileData['path']);
      } catch (e) {
        debugPrint("Error opening file: $e");
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    // Check if the user configured the vault to be here and hidden via Double-Tap
    bool isDoubleTapTrigger = _vaultLocation == 'Vault Section' && 
                              _vaultIsHidden && 
                              _vaultTrigger == 'Double-Tap Title';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Soft background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // If they chose Double-Tap, the title becomes the trigger!
        title: GestureDetector(
          onDoubleTap: isDoubleTapTrigger ? _openSecretVault : null,
          child: const Text(
            'Shared Vault',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          ),
        ),
        actions: [
          // 1. THE HIDDEN TRIGGER (Heart Icon)
          if (_vaultLocation == 'Vault Section' && _vaultIsHidden && _vaultTrigger == 'Heart Icon')
            IconButton(
              icon: const Icon(Icons.favorite, color: Colors.lightBlue), // Innocent disguise!
              onPressed: _openSecretVault,
            ),
          
          // 2. THE VISIBLE ENTRANCE (If they chose NOT to hide it)
          if (_vaultLocation == 'Vault Section' && !_vaultIsHidden)
            IconButton(
              icon: const Icon(Icons.lock_outline, color: Colors.blueAccent),
              onPressed: _openSecretVault,
            ),

          // 3. THE THREE-DOT MENU (To configure the vault)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.lightBlue),
            onSelected: (value) {
              if (value == 'setup_vault') {
                _openSetupWizard();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'setup_vault',
                child: Text('Configure Secret Vault'),
              ),
            ],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.lightBlue.shade50, // Styled dropdown
          ),
        ],
      ),
      body: _buildRegularFiles(),
    );
  }

  // ---------------------------------------------------------
  // UI: REGULAR FILES (Using your light blue gradient aesthetic)
  // ---------------------------------------------------------
  Widget _buildRegularFiles() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _vaultService.getVaultFiles(), // Using your regular vault_service!
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.lightBlue));
        }

        final files = snapshot.data ?? [];

        if (files.isEmpty) {
          return const Center(
            child: Text(
              'No files yet. Start sharing!',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            final fileType = file['type'] ?? 'unknown';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                // Light blue/white gradient for regular files
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.white.withOpacity(0.9), Colors.lightBlue.shade50],
                ),
                boxShadow: [
                  BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                onTap: () => _openSecretFile(file),
                leading: CircleAvatar(
                  backgroundColor: Colors.lightBlue.shade100,
                  child: Icon(Icons.insert_drive_file, color: Colors.blueAccent.shade200, size: 20),
                ),
                title: Text(
                  file['name'] ?? 'Shared File', 
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)
                ),
                subtitle: Text(
                  'Type: $fileType', 
                  style: const TextStyle(color: Colors.black54)
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.black26),
              ),
            );
          },
        );
      },
    );
  }
}