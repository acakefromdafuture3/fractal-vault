// Location: lib/screens/category_screen.dart

import 'package:flutter/material.dart';
import '../services/vault_service.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final VaultService _vaultService = VaultService();
  String _selectedCategoryId = 'recent'; 

  final List<Map<String, dynamic>> _categories = [
    {"id": "recent", "title": "Recent Activity", "icon": Icons.access_time_filled},
    {"id": "document", "title": "Encrypted PDFs", "icon": Icons.picture_as_pdf},
    {"id": "text", "title": "Text Records", "icon": Icons.text_snippet},
    {"id": "audio", "title": "Audio Logs", "icon": Icons.audiotrack},
    {"id": "image", "title": "Image Archives", "icon": Icons.image},
    {"id": "video", "title": "Video Evidence", "icon": Icons.movie},
  ];

  // We deleted _fetchTimelineData and the initState because the StreamBuilder handles everything!

  // *** UPDATED: MASSIVE ICON VARIETY FOR DOODLES ***
  List<IconData> _getCategoryDoodles() {
    switch (_selectedCategoryId) {
      case 'document': 
        return [
          Icons.picture_as_pdf, Icons.description, Icons.article, 
          Icons.inventory_2_outlined, Icons.snippet_folder, Icons.data_object,
          Icons.assignment_late_outlined, Icons.folder_zip_outlined
        ];
      case 'text': 
        return [
          Icons.text_snippet, Icons.notes, Icons.subject, 
          Icons.terminal, Icons.code, Icons.edit_note, 
          Icons.list_alt_rounded, Icons.history_edu
        ];
      case 'audio': 
        return [
          Icons.audiotrack, Icons.headphones, Icons.mic, 
          Icons.waves, Icons.graphic_eq, Icons.settings_voice,
          Icons.volume_up_outlined, Icons.surround_sound
        ];
      case 'image': 
        return [
          Icons.image, Icons.photo, Icons.camera_alt, 
          Icons.filter_tilt_shift, Icons.auto_awesome, Icons.style,
          Icons.wallpaper, Icons.brightness_low_outlined
        ];
      case 'video': 
        return [
          Icons.movie, Icons.videocam, Icons.play_circle, 
          Icons.video_collection, Icons.animation, Icons.cast_connected,
          Icons.slow_motion_video, Icons.movie_filter
        ];
      default: 
        return [
          Icons.access_time, Icons.history, Icons.update, 
          Icons.track_changes, Icons.hourglass_empty, Icons.published_with_changes,
          Icons.av_timer, Icons.restore
        ];
    }
  }

  // A helper function to decide which stream to listen to based on the selected category
  Stream<List<Map<String, dynamic>>> _getCorrectStream() {
    if (_selectedCategoryId == 'recent') {
      return _vaultService.getRecentFiles();
    } else {
      // If a specific category is selected, we map the stream to filter out the irrelevant files
      return _vaultService.getVaultFiles().map(
        (allFiles) => allFiles.where((file) => file['type'] == _selectedCategoryId).toList()
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // LAYER 1: The Background Gradient
        Container(
          height: double.infinity,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.primary, Colors.white],
              stops: const [0.2, 0.8], 
            ),
          ),
        ),

        // LAYER 2: THE DOODLE ENGINE
        CodeDoodleBackground(icons: _getCategoryDoodles()),

        // LAYER 3: The UI Content
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              
              // SEARCH BAR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search encrypted files...",
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF90CAFF)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1), 
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30), 
                      borderSide: BorderSide.none
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // CATEGORY PILLS (Horizontal Scroll)
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
                        if (!isSelected) {
                          // Update state; the StreamBuilder automatically hears this and switches pipelines!
                          setState(() => _selectedCategoryId = category['id']);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF90CAFF) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(category['icon'], color: isSelected ? colors.primary : Colors.white, size: 20),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Text(category['title'], style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold)),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),

              // THE MAGIC STREAM BUILDER: Listens directly to Firebase
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _getCorrectStream(), // Switches based on selected pill
                  builder: (context, snapshot) {
                    // 1. Loading state
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF0D2137)));
                    }

                    // 2. Error State
                    if (snapshot.hasError) {
                      return const Center(child: Text("Decryption Error", style: TextStyle(color: Colors.redAccent)));
                    }

                    // 3. Extract Data
                    final files = snapshot.data ?? [];

                    // 4. Empty State
                    if (files.isEmpty) {
                       return const Center(child: Text("No files found.", style: TextStyle(color: Colors.white54)));
                    }

                    // 5. Build the list live!
                    return ListView.builder(
                      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 90), 
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        return _buildTimelineCard(files[index], colors);
                      },
                    );
                  },
                )
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineCard(Map<String, dynamic> file, ColorScheme colors) {
    // Need to handle timestamp conversion safely in case data is still processing
    String addedDate = "Encrypting...";
    String accessedDate = "Pending";
    
    // Firestore stores dates as Timestamps, we need to convert them
    if (file['dateAdded'] != null) {
        // Just grabbing a simple string format for now to keep it clean
        addedDate = file['dateAdded'].toDate().toString().split(' ')[0]; 
    }

    // Safely pulling the filename you logged in dashboard_screen
    String fileName = file['name'] ?? "Unknown Artifact";

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 12, color: Color(0xFF90CAFF)),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fileName, style: TextStyle(color: colors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    "Added: $addedDate\nStatus: ${file['status'] ?? 'Active'}",
                    style: TextStyle(color: colors.primary.withOpacity(0.6), fontSize: 12, height: 1.4),
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

// *** THE DYNAMIC DOODLE ENGINE ***
class CodeDoodleBackground extends StatelessWidget {
  final List<IconData> icons;
  const CodeDoodleBackground({super.key, required this.icons});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF90CAFF), // Icy Blue for the top
              Color(0xFF0D2137), // Navy for the bottom
            ],
            stops: [0.1, 0.9],
          ).createShader(bounds);
        },
        blendMode: BlendMode.srcATop,
        child: Opacity(
          opacity: 0.2, 
          child: GridView.builder(
            padding: const EdgeInsets.all(15),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 30,
              crossAxisSpacing: 30,
            ),
            itemCount: 100,
            itemBuilder: (context, index) {
              return Transform.rotate(
                angle: (index % 2 == 0) ? 0.2 : -0.2, 
                child: Icon(
                  icons[index % icons.length],
                  size: 26,
                  color: Colors.white, 
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}