// Location: lib/screens/master_pin_auth_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'dashboard_screen.dart';
import '../widgets/doodle_background.dart';

class MasterPinAuthScreen extends StatefulWidget {
  const MasterPinAuthScreen({super.key});

  @override
  State<MasterPinAuthScreen> createState() => _MasterPinAuthScreenState();
}

class _MasterPinAuthScreenState extends State<MasterPinAuthScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  String _savedPin = '';
  String _enteredPin = '';
  bool _isLoading = true;
  bool _useBiometrics = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeLock();
  }

  Future<void> _initializeLock() async {
    final prefs = await SharedPreferences.getInstance();
    _savedPin = prefs.getString('app_master_pin') ?? '';
    _useBiometrics = prefs.getBool('app_biometrics') ?? false;

    // 🔥 THE GATEKEEPER LOGIC:
    // If no PIN is set in the settings, bypass this screen entirely and go to Dashboard!
    if (_savedPin.isEmpty) {
      _bypassToDashboard();
      return;
    }

    // If a PIN IS set, stop loading and show the Lock Screen UI
    setState(() => _isLoading = false);

    // If they enabled fingerprint in settings, trigger it immediately
    if (_useBiometrics) {
      _triggerBiometrics();
    }
  }

  void _bypassToDashboard() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  Future<void> _triggerBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (canAuthenticate) {
        final bool didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Scan fingerprint to unlock Vault Terminal',
          options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
        );

        if (didAuthenticate) {
          _bypassToDashboard();
        }
      }
    } catch (e) {
      debugPrint("Biometric Error: $e");
    }
  }

  void _onPinTap(String number) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += number;
        _errorMessage = '';
      });
      
      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _verifyPin() async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (_enteredPin == _savedPin) {
      _bypassToDashboard();
    } else {
      setState(() {
        _enteredPin = '';
        _errorMessage = 'ACCESS DENIED. INCORRECT PIN.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A1526),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF90CAFF))),
      );
    }

    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: double.infinity, width: double.infinity,
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [colors.primary, const Color(0xFF0A1526)])),
          ),
          const CodeDoodleBackground(icons: [Icons.security, Icons.lock, Icons.admin_panel_settings]),
          
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                const Icon(Icons.lock_outline, size: 60, color: Color(0xFF90CAFF)),
                const SizedBox(height: 20),
                const Text("SYSTEM LOCKED", style: TextStyle(fontSize: 22, color: Colors.white, letterSpacing: 3.0, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("ENTER MASTER PIN", style: TextStyle(fontSize: 14, color: Colors.white54, letterSpacing: 1.5)),
                const SizedBox(height: 30),
                
                // PIN DOTS
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10), width: 18, height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, 
                      color: index < _enteredPin.length ? const Color(0xFF90CAFF) : Colors.transparent,
                      border: Border.all(color: const Color(0xFF90CAFF), width: 2),
                      boxShadow: index < _enteredPin.length ? [const BoxShadow(color: Color(0xFF90CAFF), blurRadius: 10)] : null,
                    ),
                  )),
                ),
                
                const SizedBox(height: 20),
                // Error Message
                SizedBox(
                  height: 20,
                  child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                ),

                if (_useBiometrics)
                  TextButton.icon(
                    onPressed: _triggerBiometrics,
                    icon: const Icon(Icons.fingerprint, color: Color(0xFF90CAFF)),
                    label: const Text("Use Biometrics", style: TextStyle(color: Color(0xFF90CAFF))),
                  ),

                const Spacer(),

                // NUMPAD
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                  child: GridView.builder(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.3, crossAxisSpacing: 15, mainAxisSpacing: 15),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      if (index == 9) return const SizedBox(); 
                      if (index == 11) {
                        return GestureDetector(
                          onTap: () { if (_enteredPin.isNotEmpty) setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1)); }, 
                          child: const Icon(Icons.backspace_outlined, color: Colors.white54)
                        );
                      }
                      final number = index == 10 ? '0' : '${index + 1}';
                      return GestureDetector(
                        onTap: () => _onPinTap(number),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20), 
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(color: Colors.white10)
                          ),
                          child: Center(child: Text(number, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}