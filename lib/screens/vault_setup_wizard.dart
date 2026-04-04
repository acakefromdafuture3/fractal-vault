// Location: lib/screens/vault_setup_wizard.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VaultSetupWizard extends StatefulWidget {
  const VaultSetupWizard({super.key});

  @override
  State<VaultSetupWizard> createState() => _VaultSetupWizardState();
}

class _VaultSetupWizardState extends State<VaultSetupWizard> {
  String _authMethod = 'Password';
  String _pin = '';

  Future<void> _saveConfig() async {
    if (_authMethod == 'Password' && _pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a 4-digit PIN!"), backgroundColor: Colors.redAccent));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vaultAuthMethod', _authMethod);
    if (_authMethod == 'Password') await prefs.setString('vaultPin', _pin);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Secret Vault Configured!"), backgroundColor: Colors.green));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D2137), // Dark theme!
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: const Text('Configure Secret Vault', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("SECURITY METHOD", style: TextStyle(color: Color(0xFF90CAFF), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            
            // Toggle Buttons
            Row(
              children: [
                Expanded(child: _buildChoiceBtn('Password', Icons.dialpad)),
                const SizedBox(width: 16),
                Expanded(child: _buildChoiceBtn('Biometrics', Icons.fingerprint)),
              ],
            ),
            
            const SizedBox(height: 40),

            // PIN Input (Only shows if Password is selected)
            if (_authMethod == 'Password') ...[
              const Text("SET 4-DIGIT PIN", style: TextStyle(color: Color(0xFF90CAFF), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 16),
              TextField(
                style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                onChanged: (val) => setState(() => _pin = val),
                decoration: InputDecoration(
                  counterText: "",
                  filled: true, fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF90CAFF))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                ),
              ),
            ],

            const Spacer(),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF90CAFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saveConfig,
                child: const Text("SAVE CONFIGURATION", style: TextStyle(color: Color(0xFF0D2137), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceBtn(String title, IconData icon) {
    bool isSelected = _authMethod == title;
    return GestureDetector(
      onTap: () => setState(() => _authMethod = title),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF90CAFF).withOpacity(0.2) : Colors.white.withOpacity(0.05),
          border: Border.all(color: isSelected ? const Color(0xFF90CAFF) : Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF90CAFF) : Colors.white54, size: 32),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: isSelected ? const Color(0xFF90CAFF) : Colors.white54, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}