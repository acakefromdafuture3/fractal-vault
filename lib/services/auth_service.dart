// lib/services/auth_service.dart

class AuthService {
  // A fake database of users for testing purposes
  final Map<String, String> _mockDatabase = {
    "ritankar@vault.com": "password123",
    "tista@vault.com": "design2026",
  };

  // The login logic
  Future<bool> login({required String email, required String password}) async {
    print("System: Attempting to log in $email...");
    
    // Simulate a 2-second network delay (makes the app feel real!)
    await Future.delayed(const Duration(seconds: 2));

    // Check if the email exists and the password matches
    if (_mockDatabase.containsKey(email) && _mockDatabase[email] == password) {
      print("System: Access Granted. Welcome to the Vault!");
      return true;
    } else {
      print("System: Access Denied. Invalid credentials.");
      return false;
    }
  }

  // The logout logic
  void logout() {
    print("System: User logged out. Vault secured.");
  }
}