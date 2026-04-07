// Location: lib/screens/operator_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  bool _showPasswordSetup = false; // 🔥 Controls the hidden password menu!

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
        setState(() => _showPasswordSetup = false); // Hide it again smoothly
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
    
    // Getting all the real data again
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
                  
                  // 🔥 TOP PROFILE CARD (Now with ALL your requested data!)
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
                        const CircleAvatar(
                          radius: 40,
                          backgroundColor: Color(0xFF1A3A5C),
                          child: Icon(Icons.person, size: 50, color: Color(0xFF90CAFF)),
                        ),
                        const SizedBox(height: 20),
                        
                        _buildDataRow("AGENT EMAIL", user?.email ?? "Offline"),
                        const Divider(color: Colors.white24, height: 25),
                        _buildDataRow("SYSTEM UID (IMMUTABLE)", uid),
                        const Divider(color: Colors.white24, height: 25),
                        
                        // 🔥 Brought the missing data back!
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

                  // 🔥 THE COLLAPSIBLE PASSWORD UI
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D2137).withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        // The clickable icon button to reveal the password box
                        ListTile(
                          onTap: () {
                            setState(() => _showPasswordSetup = !_showPasswordSetup);
                          },
                          leading: const Icon(Icons.key, color: Color(0xFF90CAFF)),
                          title: const Text("Setup Fallback Credentials", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: const Text("Create a manual override password", style: TextStyle(color: Colors.white54, fontSize: 12)),
                          trailing: Icon(
                            _showPasswordSetup ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, 
                            color: Colors.white54
                          ),
                        ),
                        
                        // 🔥 Buttery smooth slide-down animation!
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
                            : const SizedBox.shrink(), // Takes up 0 space when hidden
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

  // Helper widget to draw the text beautifully
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