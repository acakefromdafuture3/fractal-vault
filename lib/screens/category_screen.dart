// Location: lib/screens/category_screen.dart

import 'dart:io'; 
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:open_filex/open_filex.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'package:firebase_auth/firebase_auth.dart';

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
  
  // 🔥 FIX 1: Upgraded to store the complete file map per selected doc.
  // This gives _deleteSelectedFiles access to BOTH ownerId AND deletion_hash
  // without any extra Firestore round-trips — the data is already in memory.
  final Map<String, Map<String, dynamic>> _selectedDocs = {};
  
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
        cloud.downloadShardFromSupabase(fileId).catchError((_) => null), 
        cloud.downloadShardFromAppwrite(fileId).catchError((_) => null),  
        cloud.downloadShardFromCloudinary(fileId).catchError((_) => null),
        cloud.downloadShardFromLocal(fileId).catchError((_) => null),
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

      await _securityMonitor.logAuthorizedAccess(target: fileName, accessedBy: FirebaseAuth.instance.currentUser?.email ?? "Unknown");
      await OpenFilex.open(tempFile.path);

    } catch (e) {
      debugPrint("Decryption Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("CRASH: $e"), backgroundColor: Colors.redAccent));
      }
    }
  }

  // 🔥 THE HONEYPOT TRAP
  // Prevents the UI from glitching by stopping the action before it hits the server.
  Future<bool> _checkForIntruders(String actionTarget) async {
    final user = FirebaseAuth.instance.currentUser;
    bool intruderDetected = false;

    // Values are now full file maps — extract ownerId from each one.
    for (final fileMap in _selectedDocs.values) {
      final String ownerId = fileMap['ownerId'] ?? "UNKNOWN";
      if (user == null || user.uid != ownerId) {
        intruderDetected = true;
        break; 
      }
    }

    if (intruderDetected) {
      if (mounted) {
        setState(() => _selectedDocs.clear()); // Instantly clear selection so UI doesn't glitch!
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🛑 ACCESS DENIED: Unauthorized files detected in selection."),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 4),
          ),
        );
      }
      
      await _securityMonitor.logBreachAttempt(target: "MASS $actionTarget");
      return true; 
    }
    return false; 
  }

  // 🔥 FIX 3: ZERO-KNOWLEDGE BANISHMENT — PATH B PROTOCOL
  // Executes the cryptographic handshake demanded by the Firestore rule:
  //   status == "PURGED" && provided_hash == resource.data.deletion_hash
  Future<void> _deleteSelectedFiles() async {
    if (_selectedDocs.isEmpty) return;
    
    // Client-side ownership trap fires first — never hit the server with dirty data.
    if (await _checkForIntruders("FILE PURGE")) return; 

    // ─── LEGACY FILE DETECTION PASS ───────────────────────────────────────────
    // Before building the batch, check whether any selected file is a legacy
    // test file that was uploaded before the deletion_hash field existed.
    // If found, abort the entire operation and inform the user.
    final List<String> legacyFileNames = [];
    for (final entry in _selectedDocs.entries) {
      final fileMap = entry.value;
      final String? hash = fileMap['deletion_hash'] as String?;
      if (hash == null || hash.isEmpty) {
        legacyFileNames.add(fileMap['name'] ?? entry.key);
      }
    }

    if (legacyFileNames.isNotEmpty && mounted) {
      final String nameList = legacyFileNames.join(', ');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          "⚠️ LEGACY FILES DETECTED: [$nameList] predate the Zero-Knowledge protocol "
          "and have no deletion_hash. These files cannot be purged via this route. "
          "Contact your vault administrator to manually retire them.",
        ),
        backgroundColor: Colors.deepOrangeAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ));
      // Do NOT clear selection — let the user deselect legacy files manually.
      return;
    }

    // ─── TELEMETRY HEADER ─────────────────────────────────────────────────────
    debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    debugPrint("🔐 [BANISHMENT] Zero-Knowledge Purge — Path B");
    debugPrint("📦 Target count: ${_selectedDocs.length} document(s)");
    debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

    // ─── BUILD THE BANISHMENT BATCH ───────────────────────────────────────────
    final int count = _selectedDocs.length;
    final batch = FirebaseFirestore.instance.batch();

    for (final entry in _selectedDocs.entries) {
      final String docId    = entry.key;
      final Map<String, dynamic> fileMap = entry.value;

      // Retrieve the deletion_hash that was sealed into Firestore at upload time.
      // The legacy guard above already rejected null/empty hashes, so this is safe.
      final String deletionHash = (fileMap['deletion_hash'] as String?) ?? '';

      // ── DEBUG TELEMETRY: log every payload before it hits the server ────────
      debugPrint("  ┌─ Document  : $docId");
      debugPrint("  │  File name : ${fileMap['name'] ?? 'UNNAMED'}");
      debugPrint("  │  Hash sent : $deletionHash");
      debugPrint("  └─ Payload   : { status: 'PURGED', provided_hash: '$deletionHash' }");
      // ────────────────────────────────────────────────────────────────────────

      // This update must satisfy BOTH conditions of the Firestore rule simultaneously:
      //   1. request.resource.data.status == "PURGED"
      //   2. request.resource.data.provided_hash == resource.data.deletion_hash
      batch.update(
        FirebaseFirestore.instance.collection('vault_files').doc(docId),
        {
          'status'        : 'PURGED',
          'provided_hash' : deletionHash,
        },
      );
    }
    
    debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    debugPrint("🚀 [BANISHMENT] Committing batch to Firestore...");

    try {
      await batch.commit();
      debugPrint("✅ [BANISHMENT] Batch committed. $count record(s) PURGED.");
      debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      if (mounted) {
        setState(() => _selectedDocs.clear()); 
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("BANISHMENT COMPLETE: $count record(s) marked as PURGED."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } on FirebaseException catch (e) {
      // The server rejected the handshake — most likely a hash mismatch or a
      // permissions gap. Log the Firebase-specific error code for fast diagnosis.
      debugPrint("🚨 [BANISHMENT] FirebaseException — Code: ${e.code} | ${e.message}");
      debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      if (mounted) {
        setState(() => _selectedDocs.clear());
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            "🚨 FIRESTORE HANDSHAKE FAILED [${e.code}]: "
            "The server rejected the purge. Verify deletion_hash integrity or "
            "check Firestore Security Rules. Details: ${e.message}",
          ),
          backgroundColor: Colors.deepOrangeAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ));
      }
    } catch (e) { 
      // Catch-all for non-Firebase errors (network timeouts, etc.)
      debugPrint("🚨 [BANISHMENT] Unexpected error: $e");
      debugPrint("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      if (mounted) {
        setState(() => _selectedDocs.clear());
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🚨 DATABASE FIREWALL: Server blocked unauthorized purge attempt."), 
            backgroundColor: Colors.deepOrangeAccent, 
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _makeSelectedSecret() async {
    if (_selectedDocs.isEmpty) return;
    if (await _checkForIntruders("VAULT CLOAKING")) return;

    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('vaultAuthMethod')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please configure your Secret Vault first!"), backgroundColor: Colors.orangeAccent, behavior: SnackBarBehavior.floating));
      }
      return;
    }

    final int count = _selectedDocs.length;
    final batch = FirebaseFirestore.instance.batch();
    
    for (String docId in _selectedDocs.keys) {
      batch.update(FirebaseFirestore.instance.collection('vault_files').doc(docId), {'isSecret': true});
    }

    try {
      await batch.commit();
      if (mounted) {
        setState(() => _selectedDocs.clear()); 
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("SECURED: $count files moved to Secret Vault."), backgroundColor: Colors.deepPurpleAccent, behavior: SnackBarBehavior.floating));
      }
    } catch (e) { debugPrint("Error: $e"); }
  }

  void _toggleSelection(Map<String, dynamic> file) {
    final docId = file['docId'];
    final ownerId = file['ownerId'] ?? "UNKNOWN";
    setState(() { 
      if (_selectedDocs.containsKey(docId)) {
        _selectedDocs.remove(docId);
      } else {
        // Store the entire file map — ownerId, deletion_hash, name, all of it.
        _selectedDocs[docId] = Map<String, dynamic>.from(file);
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
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("DESTROY VAULT", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vault Destroyed. Files moved to public dashboard."), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
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
              if (vaultExists && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You already have one secret vault!"), backgroundColor: Colors.orangeAccent, behavior: SnackBarBehavior.floating));
              else if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultSetupWizard()));
            } else if (value == 'access') {
              if (!vaultExists && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please configure a secret vault first!"), backgroundColor: Colors.orangeAccent, behavior: SnackBarBehavior.floating));
              else if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => const SecretVaultScreen()));
            } else if (value == 'delete') {
              if (!vaultExists && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No vault exists to delete!"), backgroundColor: Colors.orangeAccent, behavior: SnackBarBehavior.floating));
              else if (mounted) _deleteSecretVault();
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