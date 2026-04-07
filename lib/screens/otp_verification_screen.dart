// Location: lib/screens/otp_verification_screen.dart

import 'package:flutter/material.dart';
import '../widgets/doodle_background.dart';
import 'reset_pin_screen.dart'; 

class OtpVerificationScreen extends StatefulWidget {
  final String validOtp; // 🔥 Passed from the EmailJS function

  const OtpVerificationScreen({super.key, required this.validOtp});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isProcessing = false;

  void _verifySequence(String enteredCode) async {
    if (enteredCode.length < 6) return; // Wait until 6 digits are entered

    setState(() => _isProcessing = true);
    
    // Tiny delay to make it feel like it's doing heavy cryptographic work
    await Future.delayed(const Duration(milliseconds: 800)); 

    if (enteredCode == widget.validOtp) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("✅ Sequence Accepted. Clearance Granted."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ));

        // Push REPLACEMENT so they can't swipe back to the OTP screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ResetPinScreen()),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _otpController.clear(); // Clear the field for a retry
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("❌ Invalid Sequence. Access Denied."),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2137),
      body: Stack(
        children: [
          const CodeDoodleBackground(icons: [Icons.mark_email_read, Icons.dialpad, Icons.security, Icons.lock_clock]),
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
                      const Icon(Icons.mark_email_unread_rounded, size: 60, color: Color(0xFF90CAFF)),
                      const SizedBox(height: 20),
                      const Text(
                        "VERIFY TRANSMISSION",
                        style: TextStyle(color: Color(0xFF90CAFF), fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "A secure 6-digit sequence has been dispatched to your terminal. Enter it below to proceed.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 30),

                      // 🔥 The Auto-Verifying Text Field
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        onChanged: _verifySequence, // Auto-triggers check on every keystroke
                        enabled: !_isProcessing,
                        style: const TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 12.0, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: "SECURE CODE",
                          labelStyle: const TextStyle(color: Color(0xFF90CAFF), fontSize: 12, letterSpacing: 2.0),
                          counterText: "", // Hides the "0/6" text
                          filled: true,
                          fillColor: const Color(0xFF0D2137),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF90CAFF), width: 2)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Processing Spinner (shows up when checking)
                      if (_isProcessing)
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(color: Color(0xFF90CAFF)),
                        )
                      else
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context), // Let them go back if they want to resend
                          icon: const Icon(Icons.arrow_back, color: Colors.white54, size: 16),
                          label: const Text("ABORT & RETURN", style: TextStyle(color: Colors.white54, fontSize: 12)),
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
}