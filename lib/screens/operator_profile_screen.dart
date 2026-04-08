// Location: lib/screens/operator_profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart'; // 🔥 NEW: For Camera/Gallery
import '../widgets/doodle_background.dart';

class OperatorProfileScreen extends StatefulWidget {
  const OperatorProfileScreen({super.key});

  @override
  State<OperatorProfileScreen> createState() => _OperatorProfileScreenState();
}

class _OperatorProfileScreenState extends State<OperatorProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isProcessing = false;
  bool _showPasswordSetup = false; 

  // 🔥 NEW: Image Picker Variables
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  // 🔥 Load the saved image when the screen boots up
  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('operator_avatar');
    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (await file.exists()) {
        setState(() => _profileImage = file);
      }
    }
  }

  // 🔥 Handle Camera or Gallery selection
  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // Close the bottom sheet
    
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80, // Compresses slightly to save phone memory
      );

      if (pickedFile != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('operator_avatar', pickedFile.path); // Save path
        setState(() => _profileImage = File(pickedFile.path)); // Update UI
      }
    } catch (e) {
      debugPrint("Image Picker Error: $e");
    }
  }

  // 🔥 Wipe the image back to default
  Future<void> _removeImage() async {
    Navigator.pop(context);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('operator_avatar');
    setState(() => _profileImage = null);
  }

  // 🔥 Tactical Bottom Sheet to choose the source
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D2137),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF90CAFF)),
              title: const Text("Camera Readout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text("Capture new visual data", style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF90CAFF)),
              title: const Text("Database Archives", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text("Select existing visual data", style: TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            if (_profileImage != null) // Only show delete if there is an image!
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                title: const Text("Purge Visual Data", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                subtitle: const Text("Revert to default operator icon", style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: _removeImage,
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _setupFallbackPassword() async {
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Password must be at least 6 characters."),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    setState(() => _isProcessing = true);
    FocusScope.of(context).unfocus(); 

    try {
      await user?.updatePassword(_passwordController.text.trim());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Fallback Credentials Secured!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ));
        _passwordController.clear();
        setState(() => _showPasswordSetup = false);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Security Protocol: Please log out and log back in first. (${e.code})"),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final creationTime = user?.metadata.creationTime?.toString().split(' ')[0] ?? "CLASSIFIED";
    final lastSignIn = user?.metadata.lastSignInTime?.toString().split(' ')[0] ?? "UNKNOWN";
    final uid = user?.uid ?? "OFFLINE-0000";

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF90CAFF)),
        title: const Text("OPERATOR DOSSIER", style: TextStyle(color: Color(0xFF90CAFF), fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        centerTitle: true,
      ),
      body: Stack(
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
          const CodeDoodleBackground(icons: [Icons.security, Icons.fingerprint, Icons.data_usage]),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D2137).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF90CAFF).withOpacity(0.5), width: 1.5),
                      boxShadow: [BoxShadow(color: const Color(0xFF90CAFF).withOpacity(0.2), blurRadius: 20)],
                    ),
                    child: Column(
                      children: [
                        
                        // 🔥 INTERACTIVE AVATAR STACK
                        GestureDetector(
                          onTap: _showImageSourceDialog,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 45,
                                backgroundColor: const Color(0xFF1A3A5C),
                                backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                                child: _profileImage == null 
                                    ? const Icon(Icons.person, size: 55, color: Color(0xFF90CAFF))
                                    : null, // Hides the icon if we have a photo
                              ),
                              // The little edit badge
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF90CAFF),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF0D2137), width: 2),
                                ),
                                child: const Icon(Icons.edit, size: 14, color: Color(0xFF0D2137)),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        _buildDataRow("AGENT EMAIL", user?.email ?? "Offline"),
                        const Divider(color: Colors.white24, height: 25),
                        _buildDataRow("SYSTEM UID (IMMUTABLE)", uid),
                        const Divider(color: Colors.white24, height: 25),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildDataRow("ENLISTMENT", creationTime),
                            _buildDataRow("LAST ACCESS", lastSignIn),
                          ],
                        ),
                        const Divider(color: Colors.white24, height: 25),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildDataRow("CLEARANCE", "MAXIMUM"),
                            _buildDataRow("STATUS", "ACTIVE", isGreen: true),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                  const Text("EMERGENCY PROTOCOLS", style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D2137).withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          onTap: () => setState(() => _showPasswordSetup = !_showPasswordSetup),
                          leading: const Icon(Icons.key, color: Color(0xFF90CAFF)),
                          title: const Text("Setup Fallback Credentials", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: const Text("Create a manual override password", style: TextStyle(color: Colors.white54, fontSize: 12)),
                          trailing: Icon(_showPasswordSetup ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white54),
                        ),
                        
                        AnimatedSize(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOutCubic,
                          child: _showPasswordSetup 
                            ? Padding(
                                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                                child: Column(
                                  children: [
                                    const Divider(color: Colors.white12),
                                    const SizedBox(height: 10),
                                    const Text(
                                      "If Google Authentication fails, this Master Password will grant you access.",
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    const SizedBox(height: 15),
                                    Container(
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                      child: TextField(
                                        controller: _passwordController,
                                        obscureText: true,
                                        decoration: InputDecoration(
                                          hintText: "Enter Override Password",
                                          prefixIcon: Icon(Icons.password, color: colors.primary.withOpacity(0.5)),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.all(16),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _isProcessing ? null : _setupFallbackPassword,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF90CAFF),
                                          foregroundColor: const Color(0xFF0D2137),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: _isProcessing 
                                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Color(0xFF0D2137)))
                                            : const Text("AUTHORIZE", style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value, {bool isGreen = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'Courier', letterSpacing: 1.5)),
        const SizedBox(height: 4),
        SelectableText(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(color: isGreen ? Colors.greenAccent : Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          cursorColor: const Color(0xFF90CAFF),
        ),
      ],
    );
  }
}