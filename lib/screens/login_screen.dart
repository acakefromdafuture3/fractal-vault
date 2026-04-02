// Location: lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
<<<<<<< Updated upstream
=======
import 'dashboard_screen.dart'; // The connection to the vault!
>>>>>>> Stashed changes

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
<<<<<<< Updated upstream
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Access Granted! Proceeding to the Vault."),
          backgroundColor: Colors.green,
        ),
=======
      // Pushes to the new dashboard!
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
>>>>>>> Stashed changes
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
<<<<<<< Updated upstream
      body: Container(
=======
      // *** HERE IS YOUR GRADIENT ***
      body: Container(
        height: double.infinity, // Ensures the gradient covers the whole screen
>>>>>>> Stashed changes
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
<<<<<<< Updated upstream
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
=======
          // *** FIX #1: SingleChildScrollView fixes the 201 pixel keyboard error! ***
          child: Center(
            child: SingleChildScrollView(
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
                      color: Colors.white, // Pure White for maximum readability
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
                    hintText: "Enter your vault ID",
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
>>>>>>> Stashed changes
            ),
          ),
        ),
      ),
    );
  }

<<<<<<< Updated upstream
=======
  // *** FIX #3: Redesigned Input Widget (Labels Outside!) ***
>>>>>>> Stashed changes
  Widget _buildSecureInput({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    required ColorScheme colors,
    bool obscureText = false,
  }) {
<<<<<<< Updated upstream
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06), 
            blurRadius: 8,
            offset: const Offset(0, 4),
=======
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The Label now sits completely outside and above the box
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            labelText,
            style: const TextStyle(
              color: Colors.white, // Crisp white label against the dark background
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
>>>>>>> Stashed changes
          ),
        ),
        Container(
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
            // *** FIX #2: The text you type is now a sleek, dark grey! ***
            style: TextStyle(color: Colors.grey.shade800, fontSize: 16),
            decoration: InputDecoration(
              hintText: hintText, // Subtle grey hint inside the box
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: Icon(icon, color: colors.primary.withOpacity(0.6)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),
        ),
      ],
    );
  }
}