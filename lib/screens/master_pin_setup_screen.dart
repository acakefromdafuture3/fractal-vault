// Location: lib/screens/master_pin_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../widgets/doodle_background.dart';

class MasterPinSetupScreen extends StatefulWidget {
  const MasterPinSetupScreen({super.key});

  @override
  State<MasterPinSetupScreen> createState() => _MasterPinSetupScreenState();
}

class _MasterPinSetupScreenState extends State<MasterPinSetupScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  String _firstPin = '';
  String _enteredPin = '';
  bool _isConfirming = false;
  bool _enableBiometrics = true;
  bool _hasBiometricHardware = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final isSupported = await _localAuth.isDeviceSupported();
    setState(() {
      _hasBiometricHardware = canCheck || isSupported;
    });
  }

  void _onPinTap(String number) async {
    if (_enteredPin.length < 4) {
      setState(() => _enteredPin += number);
      
      if (_enteredPin.length == 4) {
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (!_isConfirming) {
          // Move to confirmation step
          setState(() {
            _firstPin = _enteredPin;
            _enteredPin = '';
            _isConfirming = true;
          });
        } else {
          // Check if pins match
          if (_enteredPin == _firstPin) {
            _saveMasterLock();
          } else {
            // Failed match
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("PIN mismatch. Sequence reset."),
              backgroundColor: Colors.redAccent,
            ));
            setState(() {
              _firstPin = '';
              _enteredPin = '';
              _isConfirming = false;
            });
          }
        }
      }
    }
  }

  Future<void> _saveMasterLock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_master_pin', _enteredPin);
    await prefs.setBool('app_biometrics', _enableBiometrics && _hasBiometricHardware);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("MASTER LOCK ENGAGED."),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context); // Go back to settings
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF90CAFF)),
        title: const Text("APP STARTUP LOCK", style: TextStyle(color: Color(0xFF90CAFF), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Container(
            height: double.infinity, width: double.infinity,
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [colors.primary, const Color(0xFF0A1526)])),
          ),
          const CodeDoodleBackground(icons: [Icons.lock_outline, Icons.dialpad, Icons.security]),
          
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Icon(_isConfirming ? Icons.verified_user : Icons.lock_person, size: 50, color: const Color(0xFF90CAFF)),
                const SizedBox(height: 20),
                Text(
                  _isConfirming ? 'CONFIRM MASTER PIN' : 'SET NEW MASTER PIN', 
                  style: const TextStyle(fontSize: 18, color: Colors.white70, letterSpacing: 2.0, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 30),
                
                // PIN DOTS
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10), width: 16, height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle, 
                      color: index < _enteredPin.length ? const Color(0xFF90CAFF) : Colors.white10,
                      boxShadow: index < _enteredPin.length ? [const BoxShadow(color: Color(0xFF90CAFF), blurRadius: 10)] : null,
                    ),
                  )),
                ),
                const SizedBox(height: 40),
                
                // BIOMETRIC TOGGLE
                if (!_isConfirming && _hasBiometricHardware)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.fingerprint, color: Color(0xFF90CAFF)),
                              SizedBox(width: 10),
                              Text("Allow Biometric Unlock", style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          Switch(
                            value: _enableBiometrics,
                            onChanged: (val) => setState(() => _enableBiometrics = val),
                            activeColor: const Color(0xFF90CAFF),
                          )
                        ],
                      ),
                    ),
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