// Location: lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 1. STANDARD EMAIL LOGIN
  Future<User?> loginWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      print("System: Email Login Successful - ${result.user?.email}");
      return result.user;
    } on FirebaseAuthException catch (e) {
      print("System: Email Login Failed - ${e.message}");
      return null;
    }
  }

  // 2. STANDARD EMAIL REGISTRATION
  Future<User?> registerWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      print("System: Registration Successful - ${result.user?.email}");
      return result.user;
    } on FirebaseAuthException catch (e) {
      print("System: Registration Failed - ${e.message}");
      return null;
    }
  }

  // 3. GOOGLE SIGN IN
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger the Google Authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print("System: Google Sign-In Canceled by User");
        return null; 
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      UserCredential result = await _auth.signInWithCredential(credential);
      print("System: Google Login Successful - ${result.user?.displayName}");
      return result.user;
      
    } catch (e) {
      print("System: Google Sign-In Failed - ${e.toString()}");
      return null;
    }
  }

  // 4. SECURE LOGOUT
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      print("System: User securely logged out.");
    } catch (e) {
      print("System: Logout Failed - ${e.toString()}");
    }
  }
}