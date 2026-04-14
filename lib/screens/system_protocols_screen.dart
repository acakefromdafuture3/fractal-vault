// Location: lib/screens/system_protocols_screen.dart

import 'dart:io';
import 'dart:ui'; // 🔥 Needed for the Glassmorphism blur!
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/doodle_background.dart';
import 'login_screen.dart';
import 'operator_profile_screen.dart';
import 'master_pin_setup_screen.dart'; 
import '../services/email_service.dart';
import 'otp_verification_screen.dart';

class SystemProtocolsScreen extends StatefulWidget {
  const SystemProtocolsScreen({super.key});

  @override
  State<SystemProtocolsScreen> createState() => _SystemProtocolsScreenState();
}

class _SystemProtocolsScreenState extends State<SystemProtocolsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  
  bool _biometricsEnabled = false;
  bool _stealthModeEnabled = false; 
  bool _isAppLockEnabled = false; 
  
  bool _isProcessing = false;
  bool _isLoadingSettings = true; 

  File? _profileImage; 

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('operator_avatar'); 
    
    setState(() {
      _biometricsEnabled = (prefs.getString('vaultAuthMethod') == 'Biometrics');
      _stealthModeEnabled = prefs.getBool('stealthMode') ?? false; 
      
      _isAppLockEnabled = prefs.containsKey('app_master_pin');
      
      if (imagePath != null && imagePath.isNotEmpty) {
        final file = File(imagePath);
        if (file.existsSync()) {
          _profileImage = file;
        } else {
          _profileImage = null;
        }
      } else {
        _profileImage = null;
      }
      
      _isLoadingSettings = false; 
    });
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const MasterPinSetupScreen()));
      _loadSettings(); 
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('app_master_pin');
      await prefs.remove('app_biometrics');
      setState(() => _isAppLockEnabled = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("App Startup Lock Disabled"), 
          backgroundColor: Colors.orange,
        ));
      }
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (_isProcessing) return; 
    setState(() => _isProcessing = true); 

    final prefs = await SharedPreferences.getInstance();
    setState(() => _biometricsEnabled = value);
    
    if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (value) {
      await prefs.setString('vaultAuthMethod', 'Biometrics');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Biometric Override Enabled"), backgroundColor: Colors.green, duration: Duration(milliseconds: 800)));
      }
    } else {
      await prefs.setString('vaultAuthMethod', 'Password');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reverted to PIN Security"), backgroundColor: Colors.orange, duration: Duration(milliseconds: 800)));
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isProcessing = false); 
  }

  Future<void> _toggleStealthMode(bool value) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final prefs = await SharedPreferences.getInstance();
    setState(() => _stealthModeEnabled = value);

    if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

    await prefs.setBool('stealthMode', value);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value ? "Stealth Mode Activated" : "Stealth Mode Disabled"), backgroundColor: value ? Colors.deepPurpleAccent : Colors.blueGrey, duration: const Duration(milliseconds: 800)));
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _resetSecretVaultPin() async {
    if (_isProcessing) return;
    
    final email = user?.email ?? "operator@fractalvault.com";

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D2137),
        title: const Text("RESET SECRET PIN?", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(
          "To reset your Secret Vault PIN, a secure 6-digit code will be sent to your registered channel:\n\n$email\n\nProceed with transmission?", 
          style: const TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text("CANCEL", style: TextStyle(color: Colors.white54))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("SEND CODE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      )
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      try {
        final otpCode = await EmailService().dispatchPinResetOtp(email);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("✅ Code Dispatched: Check your inbox"), 
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ));

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationScreen(validOtp: otpCode),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("❌ Protocol Failure: $e"), 
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ));
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _terminateSession() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true); 
    await FirebaseAuth.instance.signOut(); 
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
    }
  }

  Future<void> _showOperatorProfile() async {
    if (_isProcessing) return;
    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500), 
        reverseTransitionDuration: const Duration(milliseconds: 350), 
        pageBuilder: (context, animation, secondaryAnimation) => const OperatorProfileScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final scaleCurve = CurvedAnimation(parent: animation, curve: Curves.fastLinearToSlowEaseIn, reverseCurve: Curves.easeOut);
          final fadeCurve = CurvedAnimation(parent: animation, curve: Curves.easeIn);
          return FadeTransition(opacity: fadeCurve, child: ScaleTransition(scale: Tween<double>(begin: 0.85, end: 1.0).animate(scaleCurve), child: child));
        },
      ),
    );
    if (mounted) _loadSettings(); 
  }

  // 🔥 THE FROSTED GLASS AI WINDOW
  // 🔥 THE FROSTED GLASS AI WINDOW WITH INTERNAL DOODLES
  void _showAIWindow(BuildContext context) {
    TextEditingController _chatController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, 
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0), 
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.65,
                  decoration: BoxDecoration(
                    // Slightly more opaque so the new internal doodles pop!
                    color: const Color(0xFF0D2137).withOpacity(0.75), 
                    border: Border(
                      top: BorderSide(color: const Color(0xFF90CAFF).withOpacity(0.8), width: 1.5),
                    ),
                  ),
                  // 🔥 We use a Stack here to put doodles BEHIND the chat UI
                  child: Stack(
                    children: [
                      // --- 1. THE AI DOODLE BACKGROUND ---
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.4, // Adjust this to make doodles brighter/darker
                          child: const CodeDoodleBackground(
                            // AI-specific icons!
                            icons: [Icons.smart_toy, Icons.memory, Icons.terminal, Icons.code, Icons.data_object, Icons.analytics],
                          ),
                        ),
                      ),

                      // --- 2. THE CHAT UI CONTENT ---
                      Padding(
                        padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 10),
                        child: Column(
                          children: [
                            // --- Top Header ---
                            Row(
                              children: [
                                const Icon(Icons.smart_toy, color: Color(0xFF90CAFF), size: 28),
                                const SizedBox(width: 12),
                                const Text(
                                  "SYSTEM A.I.", 
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white54),
                                  onPressed: () => Navigator.pop(context),
                                )
                              ],
                            ),
                            const Divider(color: Colors.white24, height: 30),
                            
                            // --- Dummy Chat Area ---
                            const Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.auto_awesome, color: Colors.white24, size: 50),
                                    SizedBox(height: 12),
                                    Text(
                                      "AI Core Online.\nAwaiting Ritankar's Logic Integration...", 
                                      textAlign: TextAlign.center, 
                                      style: TextStyle(color: Colors.white54, fontFamily: 'Courier')
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // --- Input Field ---
                            Container(
                              margin: const EdgeInsets.only(top: 10, bottom: 10), 
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF071320).withOpacity(0.9), 
                                borderRadius: BorderRadius.circular(24), 
                                border: Border.all(color: const Color(0xFF90CAFF).withOpacity(0.4), width: 1),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _chatController,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: const InputDecoration(
                                        hintText: "Enter system inquiry...", 
                                        hintStyle: TextStyle(color: Colors.white38),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF90CAFF),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.send, color: Color(0xFF0D2137), size: 20),
                                      onPressed: () {
                                        print("UI triggered: Send text to AI -> ${_chatController.text}");
                                        _chatController.clear();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 🔥 THIS IS THE BUILD METHOD THAT WENT MISSING!
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    ImageProvider? avatarImage;
    if (_profileImage != null) {
      avatarImage = FileImage(_profileImage!); 
    } else if (user?.photoURL != null) {
      avatarImage = NetworkImage(user!.photoURL!); 
    }

    return Stack(
      children: [
        Container(
          height: double.infinity, width: double.infinity,
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [colors.primary, Colors.white], stops: const [0.2, 0.8])),
        ),
        
        // YOUR DOODLES ARE RIGHT HERE!
        const CodeDoodleBackground(icons: [Icons.settings, Icons.build, Icons.memory, Icons.tune, Icons.admin_panel_settings, Icons.developer_board]),
        
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20), 
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("SYSTEM PROTOCOLS", style: TextStyle(color: Color(0xFF90CAFF), fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                    
                    // The trigger for the AI Window
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D2137).withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF90CAFF).withOpacity(0.5)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.smart_toy, color: Color(0xFF90CAFF)),
                        onPressed: () => _showAIWindow(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              
              Expanded(
                child: _isLoadingSettings 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF90CAFF)))
                    : IgnorePointer(
                  ignoring: _isProcessing,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      InkWell(
                        onTap: _showOperatorProfile,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: const Color(0xFF0D2137), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF90CAFF).withOpacity(0.3))),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30, backgroundColor: const Color(0xFF90CAFF).withOpacity(0.2), backgroundImage: avatarImage,
                                child: avatarImage == null ? const Icon(Icons.person, size: 35, color: Color(0xFF90CAFF)) : null,
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("OPERATOR ID:", style: TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'Courier', letterSpacing: 1.5)),
                                    Text(user?.email ?? "Offline.Agent@vault.com", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      const Text("Clearance: MAXIMUM", style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'Courier', fontWeight: FontWeight.bold)),
                                    ]),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.white54),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      const Text("SECURITY CONFIGURATIONS", style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),

                      _buildSettingsTile(
                        icon: Icons.shield_moon,
                        title: "Master App Lock",
                        subtitle: _isAppLockEnabled ? "Startup Security Active" : "Unsecured - Direct Entry",
                        trailing: Switch(
                          value: _isAppLockEnabled,
                          onChanged: _toggleAppLock,
                          activeColor: const Color(0xFF90CAFF),
                          inactiveTrackColor: Colors.white10,
                        ),
                      ),

                      _buildSettingsTile(
                        icon: Icons.fingerprint,
                        title: "Biometric Authorization",
                        subtitle: "Use fingerprint/face to unlock Secret Vault",
                        trailing: Switch(
                          value: _biometricsEnabled,
                          onChanged: _toggleBiometrics,
                          activeColor: const Color(0xFF90CAFF),
                          inactiveTrackColor: Colors.white10,
                        ),
                      ),
                      
                      _buildSettingsTile(
                        icon: Icons.lock_reset,
                        title: "Reset Secret Vault PIN",
                        subtitle: "Forgot PIN? Send email verification",
                        trailing: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                        onTap: _resetSecretVaultPin, 
                      ),

                      _buildSettingsTile(
                        icon: Icons.visibility_off,
                        title: "Stealth Mode",
                        subtitle: "Hide app contents from recent apps screen",
                        trailing: Switch(
                          value: _stealthModeEnabled, 
                          onChanged: _toggleStealthMode, 
                          activeColor: const Color(0xFF90CAFF),
                          inactiveTrackColor: Colors.white10,
                        ),
                      ),

                      const SizedBox(height: 40),

                      InkWell(
                        onTap: _terminateSession,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent, width: 1.5)),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.power_settings_new, color: Colors.redAccent, size: 24),
                              SizedBox(width: 10),
                              Text("TERMINATE SESSION", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 100), 
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, required String subtitle, required Widget trailing, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: const Color(0xFF0D2137).withOpacity(0.6), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF90CAFF).withOpacity(0.2))),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(backgroundColor: const Color(0xFF90CAFF).withOpacity(0.2), child: Icon(icon, color: const Color(0xFF90CAFF), size: 22)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        trailing: trailing,
      ),
    );
  }
}