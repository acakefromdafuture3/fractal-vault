// Location: lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import '../services/vault_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // *** NEW: Navigation State ***
  int _currentNavIndex = 1; // Defaults to 1 (The Archive/List we just built!)

  // *** VAULT LOGIC STATE ***
  final VaultService _vaultService = VaultService();
  String _selectedCategoryId = 'recent'; 
  List<Map<String, dynamic>> _currentFiles = [];
  bool _isLoading = true;

  final List<Map<String, dynamic>> _categories = [
    {"id": "recent", "title": "Recent Activity", "icon": Icons.access_time_filled},
    {"id": "document", "title": "Encrypted PDFs", "icon": Icons.picture_as_pdf},
    {"id": "text", "title": "Text Records", "icon": Icons.text_snippet},
    {"id": "audio", "title": "Audio Logs", "icon": Icons.audiotrack},
    {"id": "image", "title": "Image Archives", "icon": Icons.image},
    {"id": "video", "title": "Video Evidence", "icon": Icons.movie},
  ];

  @override
  void initState() {
    super.initState();
    _fetchTimelineData();
  }

  Future<void> _fetchTimelineData() async {
    setState(() => _isLoading = true);
    List<Map<String, dynamic>> fetchedFiles;
    
    if (_selectedCategoryId == 'recent') {
      fetchedFiles = await _vaultService.getRecentFiles();
    } else {
      List<Map<String, dynamic>> allFiles = await _vaultService.getVaultFiles();
      fetchedFiles = allFiles.where((file) => file['type'] == _selectedCategoryId).toList();
    }

    if (mounted) {
      setState(() {
        _currentFiles = fetchedFiles;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // We switch between screens based on what icon you tap at the bottom!
    final List<Widget> pages = [
      _buildPlaceholderScreen("Home / Health Overview", Icons.health_and_safety, colors),
      _buildVaultArchiveScreen(colors), // Our masterpiece screen
      _buildPlaceholderScreen("Security Logs", Icons.security, colors),
      _buildPlaceholderScreen("Vault Settings", Icons.settings, colors),
    ];

    return Scaffold(
      extendBody: true, // Crucial: lets the gradient flow UNDER the bottom nav bar!
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Fractal Vault",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        centerTitle: true,
      ),
      
      // The current page being displayed
      body: pages[_currentNavIndex],

      // *** THE MIDDLE DOCKED '+' BUTTON ***
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // *** ADD THIS LINE: This instantly kills the old turtle! ***
          ScaffoldMessenger.of(context).hideCurrentSnackBar(); 
          
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: const Text("Secure Encryptor initialized..."), 
               backgroundColor: colors.primary,
               behavior: SnackBarBehavior.floating,
               margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
             )
          );
        },
        backgroundColor: const Color(0xFF90CAFF), 
        foregroundColor: const Color(0xFF0D2137), 
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // *** THE PREMIUM BOTTOM NAVIGATION BAR ***
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF0D2137), // Solid Dark Navy to anchor the screen
        shape: const CircularNotchedRectangle(), // Creates the cutout for the FAB!
        notchMargin: 8,
        elevation: 0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Index 0: Home
              _buildNavIcon(0, Icons.grid_view_rounded),
              // Index 1: Archive (Our main screen)
              _buildNavIcon(1, Icons.folder_special),
              
              const SizedBox(width: 40), // The empty space where the Floating button sits!
              
              // Index 2: Security
              _buildNavIcon(2, Icons.shield_outlined),
              // Index 3: Settings
              _buildNavIcon(3, Icons.settings_outlined),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for the Bottom Nav Icons
  Widget _buildNavIcon(int index, IconData icon) {
    final isSelected = _currentNavIndex == index;
    return IconButton(
      icon: Icon(
        icon, 
        color: isSelected ? const Color(0xFF90CAFF) : Colors.white.withOpacity(0.4),
        size: 28,
      ),
      onPressed: () => setState(() => _currentNavIndex = index),
    );
  }

  // *** OUR MAIN VAULT ARCHIVE SCREEN (With Search Bar!) ***
  Widget _buildVaultArchiveScreen(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.primary, 
            Colors.white,   
          ],
          stops: const [0.2, 0.8], // Adjusted to give the top section more breathing room
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            
            // *** NEW: THE SLEEK SEARCH BAR ***
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Search encrypted files...",
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF90CAFF)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1), // Translucent white glass effect
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30), 
                    borderSide: BorderSide.none
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // *** THE HORIZONTAL EXPANDING ROW ***
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
                        setState(() => _selectedCategoryId = category['id']);
                        _fetchTimelineData();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF90CAFF) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              category['icon'],
                              color: isSelected ? colors.primary : Colors.white,
                              size: 20,
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Text(
                                category['title'],
                                style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),
                              ),
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

            // *** THE TIMELINE CONTENT ***
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D2137)))
                  : _currentFiles.isEmpty
                      ? Center(child: Text("No files found in this sector.", style: TextStyle(color: colors.primary.withOpacity(0.5))))
                      : ListView.builder(
                          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 90), // Added bottom padding so files don't hide under the nav bar!
                          itemCount: _currentFiles.length,
                          itemBuilder: (context, index) {
                            final file = _currentFiles[index];
                            return _buildTimelineCard(file, colors);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(Map<String, dynamic> file, ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF90CAFF), 
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2), 
                ),
              ),
              Container(
                width: 2,
                height: 70, 
                color: const Color(0xFF90CAFF).withOpacity(0.5),
              )
            ],
          ),
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
                  Text(
                    file['fileName'],
                    style: TextStyle(color: colors.primary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Added: ${file['dateAdded']}\nAccessed: ${file['lastAccessed']}",
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

  // *** DUMMY SCREENS FOR THE OTHER NAV BUTTONS ***
  Widget _buildPlaceholderScreen(String title, IconData icon, ColorScheme colors) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [colors.primary, Colors.white], stops: const [0.2, 0.8],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: const Color(0xFF90CAFF)),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(color: colors.primary, fontSize: 24, fontWeight: FontWeight.bold), // Dark text because it sits on the white part of the gradient!
            ),
            const SizedBox(height: 10),
            Text(
              "UI Construction in Progress",
              style: TextStyle(color: colors.primary.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }
}