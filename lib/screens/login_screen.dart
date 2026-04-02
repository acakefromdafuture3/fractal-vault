// Location: lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart'; // Wires directly into Ritankar's gears!

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService(); // Accessing the background logic
  bool _isLoading = false;

  void _handleLogin() async {
    // 1. Show the loading spinner
    setState(() => _isLoading = true);
    
    // 2. Call Ritankar's code and wait for the result
    bool success = await _authService.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    // 3. Hide the loading spinner
    if(mounted) setState(() => _isLoading = false);

    // 4. Feedback (We will add the actual "Dashboard" navigation later!)
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Access Granted! Proceeding to the Vault."),
          backgroundColor: Colors.green, // Security success
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Access Denied. Please verify credentials."),
          backgroundColor: Color(0xFFE05252), // Grounded red for error
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Using Tista's palette automatically defined in main.dart
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // *** THE BRANDING SECTION ***
              const Icon(
                Icons.fingerprint, // Icon suggesting security and identity
                size: 90, 
                color: Color(0xFF33D1EE), // Our Cyan tech accent
              ),
              const SizedBox(height: 20),
              Text(
                "Fractal Vault",
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: colors.primary, // Deep Navy for the title
                  fontWeight: FontWeight.w800, // Bold and authoritative
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Secure Identity Verification",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.primary.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 60),

              // *** INPUT FIELDS SECTION ***
              // Email Field
              _buildSecureInput(
                controller: _emailController,
                labelText: "Auth ID / Email",
                icon: Icons.person_outline,
                colors: colors,
              ),
              const SizedBox(height: 20),
              
              // Password Field
              _buildSecureInput(
                controller: _passwordController,
                labelText: "Security Key / Password",
                icon: Icons.vpn_key_outlined,
                obscureText: true,
                colors: colors,
              ),
              const SizedBox(height: 10),
              
              // A "Forgot Password?" hint adds professional polish
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {}, // Do nothing for now
                  child: Text("Recover Security Key", style: TextStyle(color: colors.primary.withOpacity(0.6))),
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
                          backgroundColor: colors.primary, // Navy Blue (Grounding)
                          foregroundColor: Colors.white,
                          elevation: 2, // A subtle shadow for depth
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
    );
  }

  // A little design helper function to keep the code clean
  Widget _buildSecureInput({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    required ColorScheme colors,
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // Pure white inside the input looks clean
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), // Ultra-subtle shadow
            blurRadius: 6,
            offset: const Offset(0, 3),
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