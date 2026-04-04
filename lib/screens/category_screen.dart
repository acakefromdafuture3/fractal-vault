// Location: lib/screens/category_screen.dart

import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:open_filex/open_filex.dart'; 

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  String _selectedCategoryId = 'recent'; 
  final Set<String> _selectedDocs = {}; 
  
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
    final db = FirebaseFirestore.instance.collection('vault_files').orderBy('dateAdded', descending: true);
    
    _vaultStream = db.snapshots().map((snapshot) {
      final allFiles = snapshot.docs.map((doc) {
        var data = doc.data();
        data['docId'] = doc.id; 
        return data;
      }).toList();

      if (_selectedCategoryId == 'recent') {
        return allFiles;
      } else {
        return allFiles.where((file) => file['type'] == _selectedCategoryId).toList();
      }
    });
  }

  Future<void> _openVaultFile(Map<String, dynamic> fileData) async {
    final String fileName = fileData['name'] ?? "Unknown";
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 15),
            Expanded(child: Text("Decrypting: $fileName...", overflow: TextOverflow.ellipsis)),
          ],
        ),
        backgroundColor: const Color(0xFF0D2137),
        duration: const Duration(seconds: 1), 
      ),
    );

    // Wait for the animation
    await Future.delayed(const Duration(seconds: 1));

    // 🔥 THE KILL SWITCH: If the user selected a file while this was loading, abort the opening process!
    if (_selectedDocs.isNotEmpty || !mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      return; 
    }

    if (fileData['path'] != null) {
      try {
        File physicalFile = File(fileData['path']);
        
        if (!await physicalFile.exists()) {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("SYSTEM ERROR: Local cache missing."), backgroundColor: Colors.redAccent)
            );
          }
          return; 
        }

        final result = await OpenFilex.open(fileData['path']);
        
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("OS Warning: ${result.message}"), backgroundColor: Colors.orange)
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("CRASH: $e"), backgroundColor: Colors.red)
          );
        }
      }
    }
  }

  Future<void> _deleteSelectedFiles() async {
    if (_selectedDocs.isEmpty) return;

    final int count = _selectedDocs.length;
    final batch = FirebaseFirestore.instance.batch();
    
    for (String docId in _selectedDocs) {
      DocumentReference ref = FirebaseFirestore.instance.collection('vault_files').doc(docId);
      batch.delete(ref);
    }

    try {
      await batch.commit();
      if (mounted) {
        setState(() { _selectedDocs.clear(); }); 
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("PURGE COMPLETE: $count records destroyed."),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    } catch (e) {
      debugPrint("Batch Delete Error: $e");
    }
  }

  void _toggleSelection(String docId) {
    setState(() {
      if (_selectedDocs.contains(docId)) {
        _selectedDocs.remove(docId);
      } else {
        _selectedDocs.add(docId);
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

  IconData _getFileIcon(String type) {
    switch (type) {
      case 'image': return Icons.image;
      case 'document': return Icons.picture_as_pdf;
      case 'text': return Icons.text_snippet;
      case 'audio': return Icons.audiotrack;
      case 'video': return Icons.movie;
      default: return Icons.insert_drive_file;
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [colors.primary, Colors.white], stops: const [0.2, 0.8], 
            ),
          ),
        ),
        CodeDoodleBackground(icons: _getCategoryDoodles()), 
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: isSelectionMode 
                  ? _buildSelectionHeader() 
                  : _buildSearchBar(),
              ),

              const SizedBox(height: 24),
              
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected = _selectedCategoryId == category['id'];
                    return GestureDetector(
                      onTap: () {
                        if (!isSelectionMode && !isSelected) {
                          setState(() {
                            _selectedCategoryId = category['id'];
                            _refreshStream(); 
                          });
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF90CAFF) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: Row(
                            children: [
                              Icon(category['icon'], color: isSelected ? colors.primary : Colors.white, size: 20),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                Text(category['title'], style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
                              ]
                            ],
                          ),
                        ),
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
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF90CAFF)));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)));
                    }
                    final files = snapshot.data ?? [];
                    if (files.isEmpty) {
                      return const Center(child: Text("NO RECORDS FOUND.", style: TextStyle(color: Colors.white54, letterSpacing: 2)));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 90), 
                      itemCount: files.length,
                      itemBuilder: (context, index) => _buildTacticalCard(files[index], colors, isSelectionMode),
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

  Widget _buildSearchBar() {
    return TextField(
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: "Search encrypted records...",
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: const Icon(Icons.search, color: Color(0xFF90CAFF)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1), 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildSelectionHeader() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137), 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF90CAFF).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() => _selectedDocs.clear()),
                tooltip: 'Cancel',
              ),
              Text(
                "${_selectedDocs.length} SELECTED", 
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 26),
            onPressed: _deleteSelectedFiles, 
            tooltip: 'Purge Selected',
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalCard(Map<String, dynamic> file, ColorScheme colors, bool isSelectionMode) {
    String addedDate = "00:00:00"; 
    if (file['dateAdded'] != null && file['dateAdded'] is Timestamp) {
        addedDate = (file['dateAdded'] as Timestamp).toDate().toString().split('.')[0]; 
    }

    final String docId = file['docId']; 
    final bool isSelected = _selectedDocs.contains(docId);

    return GestureDetector(
      behavior: HitTestBehavior.opaque, 
      onLongPress: () {
        if (!isSelectionMode) { 
          _toggleSelection(docId);
        }
      },
      onTap: () {
        if (isSelectionMode) {
          _toggleSelection(docId); 
        } else {
          _openVaultFile(file); 
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF90CAFF).withOpacity(0.15) : const Color(0xFF0D2137).withOpacity(0.6),
          borderRadius: BorderRadius.circular(10), 
          border: Border.all(
            color: isSelected ? const Color(0xFF90CAFF) : Colors.white.withOpacity(0.08), 
            width: 1
          ),
        ),
        child: Row(
          children: [
            if (isSelectionMode)
              Container(
                margin: const EdgeInsets.only(right: 16),
                width: 24, height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: isSelected ? const Color(0xFF90CAFF) : Colors.white54, width: 2),
                  color: isSelected ? const Color(0xFF90CAFF) : Colors.transparent,
                ),
                child: isSelected ? const Icon(Icons.check, size: 16, color: Color(0xFF0D2137)) : null,
              )
            else
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8), 
                ),
                child: Icon(_getFileIcon(file['type'] ?? ''), color: const Color(0xFF90CAFF), size: 24),
              ),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file['name'] ?? "UNKNOWN_ARTIFACT", 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis, 
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "LOG: $addedDate  |  STAT: ${file['status']?.toUpperCase() ?? 'SECURED'}", 
                    style: TextStyle(
                      color: const Color(0xFF90CAFF).withOpacity(0.7), 
                      fontSize: 10, 
                      fontWeight: FontWeight.w600, 
                      fontFamily: 'Courier', 
                      letterSpacing: 1.0
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CodeDoodleBackground extends StatelessWidget {
  final List<IconData> icons;
  const CodeDoodleBackground({super.key, required this.icons});

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
            padding: const EdgeInsets.all(15),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5, mainAxisSpacing: 30, crossAxisSpacing: 30,
            ),
            itemCount: 100,
            itemBuilder: (context, index) => Transform.rotate(
              angle: (index % 2 == 0) ? 0.2 : -0.2,
              child: Icon(icons[index % icons.length], size: 26, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}