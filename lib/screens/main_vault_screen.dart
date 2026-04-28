import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io'; 
import 'package:open_filex/open_filex.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import '../services/security_service.dart'; 
import '../services/vault_service.dart'; 
import 'secret_vault_screen.dart'; 
import 'vault_setup_wizard.dart';

class MainVaultScreen extends StatefulWidget {
  const MainVaultScreen({Key? key}) : super(key: key);

  @override
  _MainVaultScreenState createState() => _MainVaultScreenState();
}

class _MainVaultScreenState extends State<MainVaultScreen> {
  final VaultService _vaultService = VaultService();
  final SecurityService _securityService = SecurityService(); 
  final user = FirebaseAuth.instance.currentUser; 
  
  String _vaultLocation = '';
  bool _vaultIsHidden = false;
  String _vaultTrigger = '';

  @override
  void initState() {
    super.initState();
    _loadSecretVaultSettings();
  }

  Future<void> _loadSecretVaultSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vaultLocation = prefs.getString('vaultLocation') ?? '';
      _vaultIsHidden = prefs.getBool('vaultIsHidden') ?? false;
      _vaultTrigger = prefs.getString('vaultTrigger') ?? '';
    });
  }

  Future<void> _openSetupWizard() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VaultSetupWizard()),
    );
    _loadSecretVaultSettings(); 
  }

  void _openSecretVault() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SecretVaultScreen()),
    );
  }

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
        await OpenFilex.open(fileData['path']);
      } catch (e) {
        debugPrint("Error opening file: $e");
      }
    }
  }

  // 🔥 THE UNIVERSAL BOUNCER (Blocks Deleting AND Moving)
 // 🔥 THE UNIVERSAL BOUNCER (Blocks Deleting AND Moving)
  Future<void> _attemptSecureAction(String actionType, Map<String, dynamic> fileData) async {
    final fileOwnerId = fileData['ownerId'] ?? "UNKNOWN_OWNER";
    final docId = fileData['docId']; // We need the Document ID for Firestore!

    if (docId == null) {
      debugPrint("Error: No document ID found for this file.");
      return;
    }
    
    // CHECK THE ID - If it doesn't match, spring the trap!
    if (user == null || user!.uid != fileOwnerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🛑 ACCESS DENIED: You lack clearance to $actionType '${fileData['name']}'."),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );

      _securityService.logBreachAttempt(
        target: "UNAUTHORIZED FILE ${actionType.toUpperCase()}: ${fileData['name']}",
        ipAddress: "DETECTING...", 
        location: "Cross-Account Breach Attempt",
        deviceType: Platform.operatingSystem,
      );
      
      return; // Stops the execution dead in its tracks.
    } 

    // IF THEY ARE THE REAL OWNER, talk to the secure backend!
    try {
      if (actionType == 'delete') {
        // CALL THE BACKEND!
        await _vaultService.deleteFile(docId, fileOwnerId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("File permanently shattered and deleted."), backgroundColor: Colors.green),
        );
      } 
      else if (actionType == 'move to secret vault') {
        // CALL THE BACKEND!
        await _vaultService.moveFileToSecret(docId, fileOwnerId);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payload cloaked. Moved to Secret Vault."), backgroundColor: Colors.cyan),
        );
      }
    } catch (e) {
      debugPrint("Secure Action Failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDoubleTapTrigger = _vaultLocation == 'Vault Section' && 
                              _vaultIsHidden && 
                              _vaultTrigger == 'Double-Tap Title';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: GestureDetector(
          onDoubleTap: isDoubleTapTrigger ? _openSecretVault : null,
          child: const Text(
            'Shared Vault',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          ),
        ),
        actions: [
          if (_vaultLocation == 'Vault Section' && _vaultIsHidden && _vaultTrigger == 'Heart Icon')
            IconButton(
              icon: const Icon(Icons.favorite, color: Colors.lightBlue),
              onPressed: _openSecretVault,
            ),
          
          if (_vaultLocation == 'Vault Section' && !_vaultIsHidden)
            IconButton(
              icon: const Icon(Icons.lock_outline, color: Colors.blueAccent),
              onPressed: _openSecretVault,
            ),

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
            color: Colors.lightBlue.shade50, 
          ),
        ],
      ),
      body: _buildRegularFiles(),
    );
  }

  Widget _buildRegularFiles() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _vaultService.getVaultFiles(), 
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
                // 🔥 THE NEW MENU FOR FILES (Both actions are trapped!)
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: Colors.black45),
                  onSelected: (value) {
                    _attemptSecureAction(value, file);
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem(
                      value: 'move to secret vault',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_off, color: Colors.black54, size: 18),
                          SizedBox(width: 8),
                          Text('Cloak Payload (Move to Secret)'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Text('Permanently Shatter (Delete)', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}