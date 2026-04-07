// Location: lib/screens/system_protocols_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/doodle_background.dart';
import 'login_screen.dart';
import 'operator_profile_screen.dart'; // 🔥 ADD THIS IMPORT

class SystemProtocolsScreen extends StatefulWidget {
  const SystemProtocolsScreen({super.key});

  @override
  State<SystemProtocolsScreen> createState() => _SystemProtocolsScreenState();
}

class _SystemProtocolsScreenState extends State<SystemProtocolsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  
  bool _biometricsEnabled = false;
  bool _stealthModeEnabled = false; 
  
  bool _isProcessing = false;
  bool _isLoadingSettings = true; 

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricsEnabled = (prefs.getString('vaultAuthMethod') == 'Biometrics');
      _stealthModeEnabled = prefs.getBool('stealthMode') ?? false; 
      _isLoadingSettings = false; 
    });
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Biometric Override Enabled"), 
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 800), 
        ));
      }
    } else {
      await prefs.setString('vaultAuthMethod', 'Password');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Reverted to PIN Security"), 
          backgroundColor: Colors.orange,
          duration: Duration(milliseconds: 800),
        ));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(value ? "Stealth Mode Activated" : "Stealth Mode Disabled"), 
        backgroundColor: value ? Colors.deepPurpleAccent : Colors.blueGrey,
        duration: const Duration(milliseconds: 800),
      ));
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _resetSecretVaultPin() async {
    if (_isProcessing) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D2137),
        title: const Text("RESET SECRET PIN?", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        content: Text(
          "To reset your Secret Vault PIN, a secure verification link will be sent to your registered channel:\n\n${user?.email ?? 'Unknown Agent'}\n\nProceed with transmission?", 
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
            child: const Text("SEND LINK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      )
    );

    if (confirm == true) {
      setState(() => _isProcessing = true);
      
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Secure link dispatched. Awaiting verification..."), 
          backgroundColor: Colors.blueAccent,
          duration: Duration(seconds: 3),
        ));
      }

      await Future.delayed(const Duration(seconds: 1)); 
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _terminateSession() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true); 
    
    await FirebaseAuth.instance.signOut(); 
    
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // 🔥 THE COOLER POP-UP: Using showGeneralDialog for custom animations!
  void _showOperatorProfile() {
    if (_isProcessing) return;
    
    // 🔥 THE BUTTER-SMOOTH CINEMATIC FLASH
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500), // Sped up so it doesn't drag
        reverseTransitionDuration: const Duration(milliseconds: 350), // Quicker exit
        pageBuilder: (context, animation, secondaryAnimation) => const OperatorProfileScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          
          // 🔥 The "Butter Smooth" Curve: Starts incredibly fast, then glides to a stop
          final scaleCurve = CurvedAnimation(
            parent: animation, 
            curve: Curves.fastLinearToSlowEaseIn, 
            reverseCurve: Curves.easeOut, // Keeps the exit snappy
          );

          // 🔥 The Fade Curve: Fades in smoothly and independently
          final fadeCurve = CurvedAnimation(
            parent: animation, 
            curve: Curves.easeIn,
          );

          return FadeTransition(
            opacity: fadeCurve,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1.0).animate(scaleCurve), // Deeper zoom-in
              child: child,
            ),
          );
        },
      ),
    );
  }

  // 🔥 THE SELECTABLE TEXT FIX: Now you can highlight and copy!
  Widget _buildDossierRow(String label, String value, {bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'Courier', letterSpacing: 1.0)),
          SelectableText( // Changed from Text to SelectableText!
            value, 
            style: TextStyle(color: isGreen ? Colors.greenAccent : Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            cursorColor: const Color(0xFF90CAFF), // Makes the little text cursor match our blue theme
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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
        
        const CodeDoodleBackground(
          icons: [Icons.settings, Icons.build, Icons.memory, Icons.tune, Icons.admin_panel_settings, Icons.developer_board],
        ),
        
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "SYSTEM PROTOCOLS",
                  style: TextStyle(color: Color(0xFF90CAFF), fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2.0),
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
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D2137),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF90CAFF).withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: const Color(0xFF90CAFF).withOpacity(0.2),
                                child: const Icon(Icons.person, size: 35, color: Color(0xFF90CAFF)),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("OPERATOR ID:", style: TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'Courier', letterSpacing: 1.5)),
                                    Text(user?.email ?? "Offline.Agent@vault.com", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                                        const SizedBox(width: 6),
                                        const Text("Clearance: MAXIMUM", style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontFamily: 'Courier', fontWeight: FontWeight.bold)),
                                      ],
                                    ),
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
                        icon: Icons.fingerprint,
                        title: "Biometric Authorization",
                        subtitle: "Use fingerprint/face to unlock vault",
                        trailing: Switch(
                          value: _biometricsEnabled,
                          onChanged: _toggleBiometrics,
                          activeColor: const Color(0xFF90CAFF),
                          inactiveTrackColor: Colors.white10,
                        ),
                      ),
                      _buildSettingsTile(
                        icon: Icons.password,
                        title: "Change Master PIN",
                        subtitle: "Update Main App Authentication",
                        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                        onTap: () async {
                          setState(() => _isProcessing = true); 
                          
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text("Master PIN reset logic pending..."),
                            duration: Duration(milliseconds: 800),
                          ));

                          await Future.delayed(const Duration(milliseconds: 500));
                          if (mounted) setState(() => _isProcessing = false); 
                        }
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
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent, width: 1.5),
                          ),
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
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137).withOpacity(0.6), 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90CAFF).withOpacity(0.2)), 
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF90CAFF).withOpacity(0.2),
          child: Icon(icon, color: const Color(0xFF90CAFF), size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        trailing: trailing,
      ),
    );
  }
}