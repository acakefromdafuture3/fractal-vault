// Location: lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'master_pin_auth_screen.dart'; 
import 'register_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  // 🔥 Added SingleTickerProviderStateMixin so the screen can run animations!
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // 🔥 ANIMATION VARIABLES FOR THE SCANNER
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // 🔥 Setup the breathing/pulsing animation
    _pulseController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true); // This makes it pulse in and out forever

    _pulseAnimation = Tween<double>(begin: 0.1, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    // Always clean up animations when leaving the screen!
    _pulseController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError("Please fill in all fields.");
      return;
    }

    setState(() => _isLoading = true);

    var user = await _authService.loginWithEmail(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (mounted) setState(() => _isLoading = false);

    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MasterPinAuthScreen()), 
      );
    } else {
      _showError("Access Denied. Please verify credentials.");
    }
  }

 void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    var user = await _authService.signInWithGoogle();
    if (mounted) setState(() => _isLoading = false);

    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MasterPinAuthScreen()), 
      );
    } else {
      _showError("Google Auth Failed: Check Terminal or Firebase Setup.");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFE05252)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.primary, Colors.white],
            stops: const [0.1, 0.85],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  
                  // 🔥 THE ANIMATED HOLOGRAPHIC FINGERPRINT!
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF90CAFF).withOpacity(_pulseAnimation.value * 0.5),
                              blurRadius: 40 * _pulseAnimation.value,
                              spreadRadius: 15 * _pulseAnimation.value,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.fingerprint, 
                          size: 90, 
                          color: Colors.white, // White icon looks great against the cyan glow
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  Text(
                    "Fractal Vault",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 60),
                  
                  _buildSecureInput(
                    controller: _emailController,
                    labelText: "Auth ID / Email",
                    hintText: "Enter your email",
                    icon: Icons.person_outline,
                    colors: colors,
                  ),
                  const SizedBox(height: 20),
                  
                  _buildSecureInput(
                    controller: _passwordController,
                    labelText: "Security Key / Password",
                    hintText: "••••••••••••",
                    icon: Icons.vpn_key_outlined,
                    obscureText: true,
                    colors: colors,
                  ),
                  const SizedBox(height: 40),
                  
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              height: 55,
                              child: ElevatedButton(
                                onPressed: _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text("Access Vault", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(height: 15),
                            
                            OutlinedButton.icon(
                              onPressed: _handleGoogleSignIn,
                              icon: const Icon(Icons.login, size: 18),
                              label: const Text("Sign in with Google"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.primary,
                                side: BorderSide(color: colors.primary),
                                padding: const EdgeInsets.symmetric(vertical: 15),
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            TextButton(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                              },
                              child: const Text("New Operative? Create Account"),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecureInput({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    required ColorScheme colors,
    bool obscureText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(labelText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: Icon(icon, color: colors.primary.withOpacity(0.5)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),
        ),
      ],
    );
  }
}