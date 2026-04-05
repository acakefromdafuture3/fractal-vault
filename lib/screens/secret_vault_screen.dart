// Location: lib/screens/secret_vault_screen.dart

import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:local_auth/local_auth.dart'; 
import 'package:file_picker/file_picker.dart'; 
import 'package:open_filex/open_filex.dart'; 

import '../services/secret_vault_service.dart';
import '../services/vault_service.dart';

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

  // FOLDER STATE TRACKING
  String? _activeFolderId;
  String? _activeFolderName;

  // 🔥 NEW: Tracks which files are selected for deletion!
  final Set<String> _selectedSecretDocs = {};

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
      await FirebaseFirestore.instance.collection('vault_files').doc(docId).update({
        'isSecret': false,
        'folderId': null
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("$fileName restored to public vault."), 
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating
        ));
      }
    } catch (e) {
      debugPrint("Error making public: $e");
    }
  }

  // 🔥 NEW: Delete an entire folder and everything inside it!
  Future<void> _deleteFolder(String folderId, String folderName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF5F7FA),
        title: Text("Delete '$folderName'?", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text("This folder and ALL secret files inside it will be permanently destroyed. This cannot be undone.", style: TextStyle(color: Colors.black87)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL", style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DESTROY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      )
    );

    if (confirm == true) {
      // 1. Delete all the files inside the folder first
      final files = await FirebaseFirestore.instance.collection('vault_files').where('folderId', isEqualTo: folderId).get();
      final batch = FirebaseFirestore.instance.batch();
      for(var doc in files.docs) {
        batch.delete(doc.reference);
      }
      // 2. Delete the folder itself
      batch.delete(FirebaseFirestore.instance.collection('vault_folders').doc(folderId));
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Folder and contents destroyed."), 
          backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating
        ));
      }
    }
  }

  // 🔥 NEW: Toggle Multi-Selection
  void _toggleSelection(String docId) {
    setState(() {
      if (_selectedSecretDocs.contains(docId)) {
        _selectedSecretDocs.remove(docId);
      } else {
        _selectedSecretDocs.add(docId);
      }
    });
  }

  // 🔥 NEW: Delete selected files permanently
  Future<void> _deleteSelectedSecretFiles() async {
    if (_selectedSecretDocs.isEmpty) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF5F7FA),
        title: const Text("Permanently Delete?", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to permanently destroy these ${_selectedSecretDocs.length} files?", style: const TextStyle(color: Colors.black87)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL", style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DESTROY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      )
    );

    if (confirm == true) {
      final batch = FirebaseFirestore.instance.batch();
      for (String docId in _selectedSecretDocs) {
        batch.delete(FirebaseFirestore.instance.collection('vault_files').doc(docId));
      }
      await batch.commit();

      if (mounted) {
        setState(() => _selectedSecretDocs.clear());
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Files permanently destroyed."), 
          backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating
        ));
      }
    }
  }

  Future<void> _createNewFolder() async {
    TextEditingController folderController = TextEditingController();
    
    String? folderName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF5F7FA),
        title: const Text("New Secret Folder", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: folderController,
          style: const TextStyle(color: Colors.black87),
          decoration: const InputDecoration(
            hintText: "Folder name (e.g., Photos)...",
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.lightBlue)),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black26)),
            filled: true, fillColor: Colors.white,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text("CANCEL", style: TextStyle(color: Colors.black54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.lightBlue),
            onPressed: () => Navigator.pop(context, folderController.text),
            child: const Text("CREATE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      )
    );

    if (folderName != null && folderName.trim().isNotEmpty) {
      await FirebaseFirestore.instance.collection('vault_folders').add({
        'name': folderName.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _addFileDirectlyToSecretVault() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        String originalName = result.files.single.name;
        String extension = result.files.single.extension ?? originalName.split('.').last.toLowerCase();
        
        String fileType = 'unknown';
        if (['jpg', 'jpeg', 'png'].contains(extension)) fileType = 'image';
        else if (['pdf', 'doc', 'docx'].contains(extension)) fileType = 'document';
        else if (['txt', 'csv', 'md'].contains(extension)) fileType = 'text';
        else if (['mp4', 'mkv', 'mov'].contains(extension)) fileType = 'video';
        else if (['mp3', 'wav', 'm4a'].contains(extension)) fileType = 'audio';

        await FirebaseFirestore.instance.collection('vault_files').add({
          'name': originalName,
          'path': filePath,
          'type': fileType,
          'status': 'Secured',
          'isSecret': true,
          'folderId': _activeFolderId == 'unsorted' ? null : _activeFolderId,
          'dateAdded': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("$originalName secured in vault!"), 
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
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ERROR: File missing from local storage."), backgroundColor: Colors.redAccent));
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
    final bool isSelectionMode = _selectedSecretDocs.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), 
      // 🔥 DYNAMIC APP BAR: Turns into a selection menu if files are selected!
      appBar: _isUnlocked && isSelectionMode
        ? AppBar(
            backgroundColor: const Color(0xFFF5F7FA),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.black87),
              onPressed: () => setState(() => _selectedSecretDocs.clear()),
            ),
            title: Text("${_selectedSecretDocs.length} Selected", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 28),
                onPressed: _deleteSelectedSecretFiles,
                tooltip: 'Delete Selected',
              ),
            ],
          )
        : AppBar(
            leading: _isUnlocked && _activeFolderId != null 
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => setState(() { 
                    _activeFolderId = null; 
                    _activeFolderName = null; 
                    _selectedSecretDocs.clear(); // Clear selections when leaving folder!
                  }),
                ) 
              : null,
            title: Text(
              !_isUnlocked ? 'Locked' : (_activeFolderName ?? 'Shared Secrets'),
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
                      _activeFolderId = null; 
                      _selectedSecretDocs.clear();
                    });
                    if (_authMethod == 'Biometrics') _triggerBiometrics();
                  },
                )
            ],
          ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.lightBlue))
          : _isUnlocked 
              ? (_activeFolderId == null ? _buildFolderList() : _buildVaultFiles()) 
              : (_authMethod == 'Biometrics' ? _buildBiometricLock() : _buildPinLockScreen()),
              
      // Hides the floating action button when you are trying to select/delete files
      floatingActionButton: _isUnlocked && !isSelectionMode ? FloatingActionButton.extended(
        onPressed: _activeFolderId == null ? _createNewFolder : _addFileDirectlyToSecretVault,
        backgroundColor: Colors.lightBlue,
        icon: Icon(_activeFolderId == null ? Icons.create_new_folder : Icons.add, color: Colors.white),
        label: Text(_activeFolderId == null ? "New Folder" : "Add File", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Colors.lightBlue.shade100, Colors.lightBlue.shade50]), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.1), blurRadius: 20)]),
            child: const Icon(Icons.fingerprint, size: 80, color: Colors.lightBlue),
          ),
          const SizedBox(height: 30),
          const Text('Scan Fingerprint to Unlock', style: TextStyle(fontSize: 18, color: Colors.black54)),
          const SizedBox(height: 20),
          TextButton(onPressed: _triggerBiometrics, child: const Text('Try Again', style: TextStyle(color: Colors.lightBlue, fontWeight: FontWeight.bold)))
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
          children: List.generate(4, (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 10), width: 16, height: 16,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: index < _enteredPin.length ? LinearGradient(colors: [Colors.lightBlue.shade400, Colors.lightBlue.shade200]) : null, color: index < _enteredPin.length ? null : Colors.lightBlue.shade50),
          )),
        ),
        const SizedBox(height: 50),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.2, crossAxisSpacing: 15, mainAxisSpacing: 15),
            itemCount: 12,
            itemBuilder: (context, index) {
              if (index == 9) return const SizedBox(); 
              if (index == 11) return GestureDetector(onTap: () { if (_enteredPin.isNotEmpty) setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1)); }, child: const Icon(Icons.backspace_outlined, color: Colors.black54));
              final number = index == 10 ? '0' : '${index + 1}';
              return GestureDetector(
                onTap: () => _onPinTap(number),
                child: Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withOpacity(0.9), Colors.lightBlue.shade100]), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Center(child: Text(number, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87))),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFolderList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('vault_folders').orderBy('createdAt').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final folders = snapshot.data?.docs ?? [];

        return ListView.builder(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
          itemCount: folders.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildFolderTile('unsorted', 'Unsorted Secrets', Icons.all_inbox);
            }
            final folder = folders[index - 1];
            return _buildFolderTile(folder.id, folder['name'], Icons.folder);
          }
        );
      }
    );
  }

  Widget _buildFolderTile(String id, String name, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: [Colors.white.withOpacity(0.9), Colors.lightBlue.shade50]),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Icon(icon, color: Colors.lightBlue, size: 30),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
        
        // 🔥 NEW: Trash Can for Custom Folders, Chevron for Unsorted
        trailing: id == 'unsorted' 
          ? const Icon(Icons.chevron_right, color: Colors.black26)
          : IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _deleteFolder(id, name),
              tooltip: "Delete Folder",
            ),
        onTap: () {
          setState(() {
            _activeFolderId = id;
            _activeFolderName = name;
          });
        },
      ),
    );
  }

  Widget _buildVaultFiles() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _secretService.getSecretFiles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.lightBlue));
        }

        final allSecretFiles = snapshot.data ?? [];
        
        final folderFiles = allSecretFiles.where((file) {
          if (_activeFolderId == 'unsorted') return file['folderId'] == null;
          return file['folderId'] == _activeFolderId;
        }).toList();

        if (folderFiles.isEmpty) {
          return const Center(child: Text('This folder is empty.', style: TextStyle(color: Colors.black54, fontSize: 16)));
        }

        final isSelectionMode = _selectedSecretDocs.isNotEmpty;

        return ListView.builder(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100), 
          itemCount: folderFiles.length,
          itemBuilder: (context, index) {
            final file = folderFiles[index];
            final docId = file['docId']; 
            final isSelected = _selectedSecretDocs.contains(docId);
            
            return Dismissible(
              key: Key(docId),
              // Disables swipe-to-restore if you are currently trying to multi-select
              direction: isSelectionMode ? DismissDirection.none : DismissDirection.startToEnd, 
              onDismissed: (direction) => _removeSecret(docId, file['name'] ?? 'Classified File'),
              background: Container(
                margin: const EdgeInsets.only(bottom: 16),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20),
                decoration: BoxDecoration(color: Colors.green.shade400, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.public, color: Colors.white),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  
                  // 🔥 Highlights the item in blue if it is selected!
                  border: isSelected ? Border.all(color: Colors.lightBlue, width: 2) : null,
                  color: isSelected ? Colors.lightBlue.withOpacity(0.1) : null,
                  
                  gradient: isSelected ? null : LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Colors.white.withOpacity(0.9), Colors.lightBlue.shade50]),
                  boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  
                  // 🔥 Long Press selects the item!
                  onLongPress: () {
                    if (!isSelectionMode) _toggleSelection(docId);
                  },
                  
                  // 🔥 Tapping toggles selection (if mode is active), otherwise it opens the file
                  onTap: () {
                    if (isSelectionMode) {
                      _toggleSelection(docId);
                    } else {
                      _openSecretFile(file);
                    }
                  }, 
                  
                  leading: isSelected 
                    ? const Icon(Icons.check_circle, color: Colors.lightBlue, size: 28)
                    : CircleAvatar(backgroundColor: Colors.lightBlue.shade100, child: const Icon(Icons.lock, color: Colors.blueAccent, size: 20)),
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