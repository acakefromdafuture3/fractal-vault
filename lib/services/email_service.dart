// Location: lib/services/email_service.dart

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  
  /// Generates a 6-digit OTP, sends it via EmailJS, and returns the code.
  /// Throws an Exception if the network request fails.
  Future<String> dispatchPinResetOtp(String email) async {
    // 1. Fetch credentials securely from .env
    final serviceId = dotenv.env['EMAILJS_SERVICE_ID'] ?? '';
    final templateId = dotenv.env['EMAILJS_TEMPLATE_ID'] ?? '';
    final publicKey = dotenv.env['EMAILJS_PUBLIC_KEY'] ?? '';

    // 2. Generate a random 6-digit Secure Code
    final String otpCode = (Random().nextInt(900000) + 100000).toString();

    // 3. Fire the API Payload
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': publicKey,
        'template_params': {
          'email': email, 
          'otp': otpCode, 
        }
      }),
    );

    // 4. Return the code if successful, otherwise throw an error
    if (response.statusCode == 200) {
      return otpCode; 
    } else {
      throw Exception("Failed to send: ${response.body}");
    }
  }
}