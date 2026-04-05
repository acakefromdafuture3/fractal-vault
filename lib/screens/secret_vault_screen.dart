// Location: lib/screens/secret_vault_screen.dart

import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart'; 
import 'package:file_picker/file_picker.dart'; 
import 'package:open_filex/open_filex.dart'; 

import '../services/secret_vault_service.dart';
import '../services/vault_service.dart'; // 🔥 ADDED: Hooking into Ritankar's Engine

class SecretVaultScreen extends StatefulWidget {
  const SecretVaultScreen({Key? key}) : super(key: key);

  @override
  _SecretVaultScreenState createState() => _SecretVaultScreenState();
}

class _SecretVaultScreenState extends State<SecretVaultScreen> {
  final SecretVaultService _secretService = SecretVaultService();
  final LocalAuthentication _localAuth = LocalAuthentication(); 
  
  String _enteredPin = '';
  bool _isUnlocked = false;
  bool _isLoading = true; 
  String _authMethod = 'Password'; 

  @override
  void initState() {
    super.initState();
    _loadVaultConfiguration();
  }

  Future<void> _loadVaultConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _authMethod = prefs.getString('vaultAuthMethod') ?? 'Password';
      _isLoading = false;
    });

    if (_authMethod == 'Biometrics') {
      _triggerBiometrics();
    }
  }

  Future<void> _triggerBiometrics() async {
    setState(() => _isLoading = true);
    
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (canAuthenticate) {
        final bool didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Scan fingerprint to access Secret Vault',
          options: const AuthenticationOptions(
            biometricOnly: true, 
            stickyAuth: true, 
          ),
        );

        if (didAuthenticate) {
          setState(() { _isUnlocked = true; _isLoading = false; });
        } else {
          setState(() => _isLoading = false);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication Failed'), backgroundColor: Colors.redAccent));
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No biometric hardware found on this device!'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Biometric Error: $e");
    }
  }

  Future<void> _verifyPinWithBackend() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1)); 

    final prefs = await SharedPreferences.getInstance();
    final correctPin = prefs.getString('vaultPin') ?? '1234';

    if (_enteredPin == correctPin) { 
      setState(() {
        _isUnlocked = true;
        _isLoading = false;
      });
    } else {
      setState(() {
        _enteredPin = ''; 
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Incorrect Vault PIN', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent.shade200,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onPinTap(String number) {
    if (_enteredPin.length < 4) {
      setState(() { _enteredPin += number; });
      if (_enteredPin.length == 4) {
        _verifyPinWithBackend();
      }
    }
  }

  Future<void> _removeSecret(String docId, String fileName) async {
    try {
      await FirebaseFirestore.instance.collection('vault_files').doc(docId).update({'isSecret': false});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("$fileName restored to public vault."), 
          backgroundColor: Colors.green, 
          behavior: SnackBarBehavior.floating
        ));
      }
    } catch (e) {
      debugPrint("Error making public: $e");
    }
  }

  Future<void> _addFileDirectlyToSecretVault() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        String fileName = result.files.single.name;
        
        // Grab extension and size safely
        String extension = result.files.single.extension ?? fileName.split('.').last.toLowerCase();
        int fileSize = result.files.single.size;

        // 🔌 THE FIX: Sending the file directly to Ritankar's Master Upload Portal!
        await VaultService().uploadFile(
          name: fileName,
          path: filePath,
          extension: extension,
          size: fileSize,
          isSecret: true, // 👈 Secret Vault
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("$fileName secured directly in vault!"), 
            backgroundColor: Colors.lightBlue,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      debugPrint("Error uploading file: $e");
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), 
      appBar: AppBar(
        title: Text(
          _isUnlocked ? 'Shared Secrets' : 'Locked', 
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (_isUnlocked)
            IconButton(
              icon: const Icon(Icons.lock_open, color: Colors.lightBlue),
              onPressed: () {
                setState(() {
                  _isUnlocked = false;
                  _enteredPin = '';
                });
                if (_authMethod == 'Biometrics') {
                  _triggerBiometrics();
                }
              },
            )
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.lightBlue))
          : _isUnlocked 
              ? _buildVaultFiles() 
              : (_authMethod == 'Biometrics' ? _buildBiometricLock() : _buildPinLockScreen()),
              
      floatingActionButton: _isUnlocked ? FloatingActionButton.extended(
        onPressed: _addFileDirectlyToSecretVault,
        backgroundColor: Colors.lightBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add File", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ) : null,
    );
  }

  Widget _buildBiometricLock() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.lightBlue.shade100, Colors.lightBlue.shade50],
              ),
              boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 20)],
            ),
            child: const Icon(Icons.fingerprint, size: 80, color: Colors.lightBlue),
          ),
          const SizedBox(height: 30),
          const Text('Scan Fingerprint to Unlock', style: TextStyle(fontSize: 18, color: Colors.black54)),
          const SizedBox(height: 20),
          TextButton(
            onPressed: _triggerBiometrics,
            child: const Text('Try Again', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildPinLockScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.favorite_border, size: 50, color: Colors.lightBlue),
        const SizedBox(height: 20),
        const Text('Enter Vault Key', style: TextStyle(fontSize: 18, color: Colors.black54, letterSpacing: 1.5)),
        const SizedBox(height: 30),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 16, height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: index < _enteredPin.length
                    ? LinearGradient(colors: [Colors.lightBlue.shade400, Colors.lightBlue.shade200])
                    : null,
                color: index < _enteredPin.length ? null : Colors.lightBlue.shade50,
              ),
            );
          }),
        ),
        
        const SizedBox(height: 50),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              if (index == 9) return const SizedBox(); 
              if (index == 11) {
                return GestureDetector(
                  onTap: () {
                    if (_enteredPin.isNotEmpty) {
                      setState(() {
                        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
                      });
                    }
                  },
                  child: const Icon(Icons.backspace_outlined, color: Colors.black54),
                );
              }
              
              final number = index == 10 ? '0' : '${index + 1}';
              return GestureDetector(
                onTap: () => _onPinTap(number),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Colors.white.withOpacity(0.9), Colors.lightBlue.shade100],
                    ),
                    boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Center(
                    child: Text(number, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVaultFiles() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _secretService.getSecretFiles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.lightBlue));
        }

        final files = snapshot.data ?? [];

        if (files.isEmpty) {
          return const Center(
            child: Text('Your shared secrets are empty.', style: TextStyle(color: Colors.black54, fontSize: 16)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100), 
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            final docId = file['docId']; 
            
            return Dismissible(
              key: Key(docId),
              direction: DismissDirection.startToEnd, 
              onDismissed: (direction) => _removeSecret(docId, file['name'] ?? 'Classified File'),
              background: Container(
                margin: const EdgeInsets.only(bottom: 16),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                decoration: BoxDecoration(
                  color: Colors.green.shade400, 
                  borderRadius: BorderRadius.circular(16)
                ),
                child: const Icon(Icons.public, color: Colors.white),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft, end: Alignment.centerRight,
                    colors: [Colors.white.withOpacity(0.9), Colors.lightBlue.shade50],
                  ),
                  boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  
                  // 🔥 WIRED UP: Tapping it opens it now!
                  onTap: () => _openSecretFile(file), 
                  
                  leading: CircleAvatar(
                    backgroundColor: Colors.lightBlue.shade100,
                    child: const Icon(Icons.lock, color: Colors.blueAccent, size: 20),
                  ),
                  title: Text(file['name'] ?? 'Classified File', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.black26),
                ),
              ),
            );
          },
        );
      },
    );
  }
}