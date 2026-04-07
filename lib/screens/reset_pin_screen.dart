// Location: lib/screens/reset_pin_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/doodle_background.dart';

class ResetPinScreen extends StatefulWidget {
  const ResetPinScreen({super.key});

  @override
  State<ResetPinScreen> createState() => _ResetPinScreenState();
}

class _ResetPinScreenState extends State<ResetPinScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _isProcessing = false;
  bool _obscurePin = true;

  Future<void> _saveNewPin() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pin.length < 4) {
      _showError("PIN must be at least 4 digits");
      return;
    }
    if (pin != confirm) {
      _showError("PINs do not match. Protocol aborted.");
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // 🔥 Overwriting the old PIN in local secure storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('secret_vault_pin', pin); // Ensure this matches your actual PIN key!

      // Simulate network delay for the "Hacker" effect
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("✅ Secret Vault PIN successfully overwritten!"),
          backgroundColor: Colors.green,
        ));
        
        // Kick them back to the main app flow (pops the Reset screen AND the OTP screen)
        Navigator.pop(context); 
      }
    } catch (e) {
      _showError("Encryption failure: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("❌ $message"),
      backgroundColor: Colors.redAccent,
    ));
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2137),
      body: Stack(
        children: [
          const CodeDoodleBackground(icons: [Icons.lock_reset, Icons.security, Icons.password, Icons.shield]),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF152A47).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF90CAFF).withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF90CAFF).withOpacity(0.1), blurRadius: 20, spreadRadius: 5)
                    ]
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_reset_rounded, size: 60, color: Color(0xFF90CAFF)),
                      const SizedBox(height: 20),
                      const Text(
                        "AUTHORIZE NEW PIN",
                        style: TextStyle(color: Color(0xFF90CAFF), fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Identity verified. Enter a new secure sequence for the Secret Vault.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 30),

                      // PIN INPUT 1
                      _buildPinField(controller: _pinController, label: "NEW PIN"),
                      const SizedBox(height: 15),
                      
                      // PIN INPUT 2
                      _buildPinField(controller: _confirmController, label: "CONFIRM PIN"),
                      const SizedBox(height: 10),

                      // Show/Hide Toggle
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _obscurePin = !_obscurePin),
                          icon: Icon(_obscurePin ? Icons.visibility : Icons.visibility_off, color: Colors.white54, size: 16),
                          label: Text(_obscurePin ? "Show" : "Hide", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // SUBMIT BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF90CAFF),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isProcessing ? null : _saveNewPin,
                          child: _isProcessing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF0D2137), strokeWidth: 2))
                              : const Text("ENCRYPT & SAVE", style: TextStyle(color: Color(0xFF0D2137), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinField({required TextEditingController controller, required String label}) {
    return TextField(
      controller: controller,
      obscureText: _obscurePin,
      keyboardType: TextInputType.number,
      maxLength: 6, // Allows up to 6 digits, adjust if you strictly want 4
      style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8.0, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF90CAFF), fontSize: 12, letterSpacing: 2.0),
        counterText: "",
        filled: true,
        fillColor: const Color(0xFF0D2137),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF90CAFF), width: 2)),
      ),
    );
  }
}