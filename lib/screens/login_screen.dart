// Location: lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService(); 
  bool _isLoading = false;

  void _handleLogin() async {
    setState(() => _isLoading = true);
    
    bool success = await _authService.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if(mounted) setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Access Granted! Proceeding to the Vault."),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Access Denied. Please verify credentials."),
          backgroundColor: Color(0xFFE05252), 
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.primary, // Deep Navy Blue at the top
              Colors.white,   // Pure White at the bottom
            ],
            stops: const [0.1, 0.85], 
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // *** THE BRANDING SECTION ***
                const Icon(
                  Icons.fingerprint,
                  size: 90, 
                  color: Color(0xFF90CAFF), // Crisp, Icy Baby-Blue
                ),
                const SizedBox(height: 20),
                Text(
                  "Fractal Vault",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: Colors.white, // Now it's Pure White!
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2, 
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Secure Identity Verification",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF90CAFF).withOpacity(0.8), // Faded blue for subtitle
                  ),
                ),
                const SizedBox(height: 60),

                // *** INPUT FIELDS SECTION ***
                _buildSecureInput(
                  controller: _emailController,
                  labelText: "Auth ID / Email",
                  icon: Icons.person_outline,
                  colors: colors,
                ),
                const SizedBox(height: 20),
                
                _buildSecureInput(
                  controller: _passwordController,
                  labelText: "Security Key / Password",
                  icon: Icons.vpn_key_outlined,
                  obscureText: true,
                  colors: colors,
                ),
                const SizedBox(height: 10),
                
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {}, 
                    child: Text("Recover Security Key", style: TextStyle(color: colors.primary.withOpacity(0.8))),
                  ),
                ),
                const SizedBox(height: 40),

                // *** THE ACTION BUTTON ***
                _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary, // Navy Blue button
                            foregroundColor: Colors.white,
                            elevation: 4, 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            "Access Vault",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecureInput({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    required ColorScheme colors,
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06), 
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(icon, color: colors.primary.withOpacity(0.6)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}