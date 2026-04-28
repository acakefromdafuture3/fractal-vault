// Location: lib/screens/category_screen.dart

import 'dart:io'; 
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:open_filex/open_filex.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; // 🔥 Needed for the trap

import '../services/vault_service.dart'; 
import '../services/security_service.dart'; 
import '../services/encryption_service.dart'; 
import '../services/cloud_dispatcher.dart';   
import 'vault_setup_wizard.dart'; 
import 'secret_vault_screen.dart'; 
import '../widgets/doodle_background.dart';
import '../widgets/tactical_file_card.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final VaultService _vaultService = VaultService();
  final SecurityService _securityMonitor = SecurityService(); 
  String _selectedCategoryId = 'recent'; 
  
  // 🔥 UPGRADED: Now stores docId AND ownerId so we can catch hackers!
  final Map<String, String> _selectedDocs = {}; 
  
  Stream<List<Map<String, dynamic>>>? _vaultStream;

  final List<Map<String, dynamic>> _categories = [
    {"id": "recent", "title": "Recent Activity", "icon": Icons.access_time_filled},
    {"id": "document", "title": "Encrypted Documents", "icon": Icons.picture_as_pdf},
    {"id": "text", "title": "Text Records", "icon": Icons.text_snippet},
    {"id": "audio", "title": "Audio Logs", "icon": Icons.audiotrack},
    {"id": "image", "title": "Image Archives", "icon": Icons.image},
    {"id": "video", "title": "Video Evidence", "icon": Icons.movie},
  ];

  @override
  void initState() {
    super.initState();
    _refreshStream(); 
  }

  void _refreshStream() {
    if (_selectedCategoryId == 'recent') {
      _vaultStream = _vaultService.getVaultFiles().map((files) {
        final sortedFiles = List<Map<String, dynamic>>.from(files);
        sortedFiles.sort((a, b) {
          final Timestamp? timeA = a['dateAdded'] as Timestamp?;
          final Timestamp? timeB = b['dateAdded'] as Timestamp?;
          if (timeA == null || timeB == null) return 0;
          return timeB.compareTo(timeA); 
        });
        return sortedFiles;
      });
    } else {
      _vaultStream = _vaultService.getVaultFiles().map(
        (files) => files.where((file) => file['type'] == _selectedCategoryId).toList()
      );
    }
  }

  Future<void> _openVaultFile(Map<String, dynamic> fileData) async {
    final String fileName = fileData['name'] ?? "Unknown";
    final String fileId = fileData['docId'];
    final String ivBase64 = fileData['iv'];
    final String extension = fileData['extension'];
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        const SizedBox(width: 15), 
        Expanded(child: Text("Scavenging Shards for: $fileName...", overflow: TextOverflow.ellipsis)),
      ]),
      backgroundColor: const Color(0xFF0D2137), duration: const Duration(seconds: 4), 
    ));

    try {
      final cloud = CloudDispatcher();

      Uint8List? encryptedBytes = await cloud.downloadEncryptedFile(fileId);
      if (encryptedBytes == null) throw Exception("Primary Node Unreachable.");

      final results = await Future.wait([
        cloud.downloadShardFromSupabase(fileId),  
        cloud.downloadShardFromAppwrite(fileId),  
        cloud.downloadShardFromCloudinary(fileId),
        cloud.downloadShardFromLocal(fileId),
      ]);

      final List<String> gatheredShards = results.whereType<String>().toList();

      if (gatheredShards.length < 3) {
        throw Exception("Quorum Failed: Need 3 shards, found ${gatheredShards.length}.");
      }

      final crypto = EncryptionService();
      String recoveredKey = crypto.rebuildAesKey(gatheredShards);
      Uint8List plainBytes = crypto.decryptHeavyFile(encryptedBytes, recoveredKey, ivBase64);

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/view_$fileId.$extension');
      await tempFile.writeAsBytes(plainBytes);

      await _securityMonitor.logAuthorizedAccess(
        target: fileName, ipAddress: "192.168.Secure", location: "Encrypted Tunnel", deviceType: "Trusted Mobile Client", accessedBy: "Verified Recipient",
      );

      await OpenFilex.open(tempFile.path);

    } catch (e) {
      debugPrint("Decryption Error: $e");
      await _securityMonitor.logBreachAttempt(
        target: fileName, ipAddress: "HOSTILE IP", location: "Unknown Origin", deviceType: "Brute Force Tool",
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("CRASH: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  // 🔥 THE CENTRAL HONEYPOT TRAP FOR BATCH ACTIONS
  Future<bool> _checkForIntruders(String actionTarget) async {
    final user = FirebaseAuth.instance.currentUser;
    bool intruderDetected = false;

    // Check every single file they selected
    for (String ownerId in _selectedDocs.values) {
      if (user == null || user.uid != ownerId) {
        intruderDetected = true;
        break; // Stop checking, we caught them!
      }
    }

    if (intruderDetected) {
      if (mounted) {
        setState(() => _selectedDocs.clear()); // Drop their selection instantly
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🛑 ACCESS DENIED: Unauthorized files detected in selection."),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 4),
          ),
        );
      }
      
      // Send them to the Radar!
      await _securityMonitor.logBreachAttempt(
        target: "MASS $actionTarget",
        ipAddress: "DETECTING...", 
        location: "Category Screen Breach",
        deviceType: Platform.operatingSystem,
      );
      return true; // Yes, an intruder was caught
    }
    return false; // Safe to proceed
  }

  Future<void> _deleteSelectedFiles() async {
    if (_selectedDocs.isEmpty) return;
    
    // 🔥 SPRING THE TRAP BEFORE DELETING
    if (await _checkForIntruders("FILE PURGE")) return; 

    final int count = _selectedDocs.length;
    final batch = FirebaseFirestore.instance.batch();
    for (String docId in _selectedDocs.keys) { // 🔥 Used .keys
      batch.delete(FirebaseFirestore.instance.collection('vault_files').doc(docId));
    }
    try {
      await batch.commit();
      if (mounted) {
        setState(() => _selectedDocs.clear()); 
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PURGE COMPLETE: $count records destroyed."), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
      }
    } catch (e) { debugPrint("Error: $e"); }
  }

  Future<void> _makeSelectedSecret() async {
    if (_selectedDocs.isEmpty) return;
    
    // 🔥 SPRING THE TRAP BEFORE MOVING
    if (await _checkForIntruders("VAULT CLOAKING")) return;

    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('vaultAuthMethod')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please configure your Secret Vault first!"), 
          backgroundColor: Colors.orangeAccent, behavior: SnackBarBehavior.floating
        ));
      }
      return;
    }

    final int count = _selectedDocs.length;
    final batch = FirebaseFirestore.instance.batch();
    
    for (String docId in _selectedDocs.keys) { // 🔥 Used .keys
      batch.update(FirebaseFirestore.instance.collection('vault_files').doc(docId), {'isSecret': true});
    }

    try {
      await batch.commit();
      if (mounted) {
        setState(() => _selectedDocs.clear()); 
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("SECURED: $count files moved to Secret Vault."), 
          backgroundColor: Colors.deepPurpleAccent, behavior: SnackBarBehavior.floating
        ));
      }
    } catch (e) { debugPrint("Error: $e"); }
  }

  // 🔥 UPGRADED SELECTION LOGIC
  void _toggleSelection(Map<String, dynamic> file) {
    final docId = file['docId'];
    final ownerId = file['ownerId'] ?? "UNKNOWN";
    
    setState(() { 
      if (_selectedDocs.containsKey(docId)) {
        _selectedDocs.remove(docId);
      } else {
        _selectedDocs[docId] = ownerId; // Save the owner ID for the trap check!
      }
    });
  }

  List<IconData> _getCategoryDoodles() {
    switch (_selectedCategoryId) {
      case 'document': return [Icons.picture_as_pdf, Icons.description, Icons.article, Icons.inventory_2_outlined];
      case 'text': return [Icons.text_snippet, Icons.notes, Icons.terminal, Icons.code];
      case 'audio': return [Icons.audiotrack, Icons.headphones, Icons.mic, Icons.waves];
      case 'image': return [Icons.image, Icons.photo, Icons.camera_alt, Icons.style];
      case 'video': return [Icons.movie, Icons.videocam, Icons.play_circle, Icons.video_collection];
      default: return [Icons.access_time, Icons.history, Icons.update, Icons.track_changes];
    }
  }

  Future<void> _deleteSecretVault() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D2137),
        title: const Text("DESTROY VAULT?", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: const Text("This will remove your security configuration. All currently hidden files will be safely moved back to the public dashboard.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL", style: TextStyle(color: Colors.white54))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("DESTROY VAULT", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('vaultAuthMethod');
      await prefs.remove('vaultPin');

      final snapshot = await FirebaseFirestore.instance.collection('vault_files').where('isSecret', isEqualTo: true).get();
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isSecret': false});
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Vault Destroyed. Files moved to public dashboard."), 
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bool isSelectionMode = _selectedDocs.isNotEmpty;

    return Stack(
      children: [
        Container(
          height: double.infinity, width: double.infinity,
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [colors.primary, Colors.white], stops: const [0.2, 0.8])),
        ),
        CodeDoodleBackground(icons: _getCategoryDoodles()), 
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: isSelectionMode ? _buildSelectionHeader() : _buildTopBar()),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategoryId == category['id'];
                    return GestureDetector(
                      onTap: () { if (!isSelectionMode && !isSelected) { setState(() { _selectedCategoryId = category['id']; _refreshStream(); }); } },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(color: isSelected ? const Color(0xFF90CAFF) : Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(30)),
                        child: Center(child: Row(children: [
                          Icon(category['icon'], color: isSelected ? colors.primary : Colors.white, size: 20),
                          if (isSelected) ...[const SizedBox(width: 8), Text(category['title'], style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold))]
                        ])),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _vaultStream, 
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF90CAFF)));
                    if (snapshot.hasError) return Center(child: Text("ERROR: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                    final files = snapshot.data ?? [];
                    if (files.isEmpty) return const Center(child: Text("NO RECORDS FOUND.", style: TextStyle(color: Colors.white54, letterSpacing: 2)));
                    return ListView.builder(
                      padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 120), 
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final file = files[index];
                        return TacticalFileCard(
                          file: file, colors: colors, isSelectionMode: isSelectionMode,
                          isSelected: _selectedDocs.containsKey(file['docId']),
                          onLongPress: () { if (!isSelectionMode) _toggleSelection(file); },
                          onTap: () { isSelectionMode ? _toggleSelection(file) : _openVaultFile(file); },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search encrypted records...", hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)), prefixIcon: const Icon(Icons.search, color: Color(0xFF90CAFF)),
              filled: true, fillColor: Colors.white.withOpacity(0.1), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        const SizedBox(width: 10),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Color(0xFF90CAFF), size: 28),
          color: const Color(0xFF0D2137), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: const Color(0xFF90CAFF).withOpacity(0.3))),
          onSelected: (value) async {
            final prefs = await SharedPreferences.getInstance();
            final vaultExists = prefs.containsKey('vaultAuthMethod'); 

            if (value == 'setup') {
              if (vaultExists && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You already have one secret vault!"), backgroundColor: Colors.orangeAccent, behavior: SnackBarBehavior.floating));
              } else if (mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultSetupWizard()));
              }
            } else if (value == 'access') {
              if (!vaultExists && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please configure a secret vault first!"), backgroundColor: Colors.orangeAccent, behavior: SnackBarBehavior.floating));
              } else if (mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SecretVaultScreen()));
              }
            } else if (value == 'delete') {
              if (!vaultExists && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No vault exists to delete!"), backgroundColor: Colors.orangeAccent, behavior: SnackBarBehavior.floating));
              } else if (mounted) {
                _deleteSecretVault();
              }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'setup', child: Row(children: [Icon(Icons.settings, color: Colors.white54, size: 20), SizedBox(width: 10), Text('Configure Secret Vault', style: TextStyle(color: Colors.white))])),
            const PopupMenuItem(value: 'access', child: Row(children: [Icon(Icons.vpn_key, color: Colors.greenAccent, size: 20), SizedBox(width: 10), Text('Access Secret Vault', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))])),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_forever, color: Colors.redAccent, size: 20), SizedBox(width: 10), Text('Delete Secret Vault', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))])),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectionHeader() {
    return Container(
      height: 48, padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: const Color(0xFF0D2137), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF90CAFF).withOpacity(0.3))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => _selectedDocs.clear())),
              Text("${_selectedDocs.length} SELECTED", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ],
          ),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.security, color: Colors.deepPurpleAccent, size: 22), onPressed: _makeSelectedSecret, tooltip: 'Make Secret'),
              IconButton(icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 26), onPressed: _deleteSelectedFiles, tooltip: 'Purge'),
            ],
          ),
        ],
      ),
    );
  }
}