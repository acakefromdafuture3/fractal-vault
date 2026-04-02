// Location: lib/screens/category_screen.dart

import 'package:flutter/material.dart';
import '../services/vault_service.dart'; // Ritankar's logic engine

class CategoryScreen extends StatefulWidget {
  final String categoryType;
  final String categoryTitle;

  const CategoryScreen({super.key, required this.categoryType, required this.categoryTitle});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final VaultService _vaultService = VaultService();
  List<Map<String, dynamic>> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  // Wires into Ritankar's mock database!
  Future<void> _loadFiles() async {
    List<Map<String, dynamic>> fetchedFiles;

    if (widget.categoryType == 'recent') {
      fetchedFiles = await _vaultService.getRecentFiles(); // Ritankar's special recent function
    } else {
      List<Map<String, dynamic>> allFiles = await _vaultService.getVaultFiles(); // Ritankar's fetch all function
      // Filter out only the ones that match this category
      fetchedFiles = allFiles.where((file) => file['type'] == widget.categoryType).toList();
    }

    setState(() {
      _files = fetchedFiles;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2137), // Deep Navy background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.categoryTitle, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Color(0xFF90CAFF)), // Back arrow color
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF90CAFF)))
          : _files.isEmpty
              ? const Center(child: Text("No secure files found.", style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    return _buildTimelineItem(file);
                  },
                ),
    );
  }

  // The Timeline Visuals
  Widget _buildTimelineItem(Map<String, dynamic> file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Line & Dot
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Color(0xFF90CAFF), // Icy blue dot
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 70, // Length of the timeline line
                color: const Color(0xFF90CAFF).withOpacity(0.3),
              )
            ],
          ),
          const SizedBox(width: 20),
          
          // The File Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF15304C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file['fileName'],
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Added: ${file['dateAdded']} • Accessed: ${file['lastAccessed']}",
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}