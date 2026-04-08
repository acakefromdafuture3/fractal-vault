// Location: lib/services/encryption_service.dart

import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;

class EncryptionService {
  // The Prime boundary for our finite field (Required for Shamir's Secret Sharing)
  final BigInt _prime = (BigInt.two.pow(521)) - BigInt.one;

  // =================================================================
  // 🔒 PHASE 1: THE UPLOAD PIPELINE (Encrypt & Shred)
  // =================================================================

  /// 1. Generate a secure 32-character Master AES Key
  String generateMasterAesKey() {
    final random = Random.secure();
    // Using safe alphanumeric characters to avoid UTF-8 encoding crashes
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    return String.fromCharCodes(Iterable.generate(32, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  /// 2. Encrypt the Heavy File (PDF/Image) using AES-256
  Map<String, dynamic> encryptHeavyFile(Uint8List fileBytes, String aesKeyString) {
    final key = enc.Key.fromUtf8(aesKeyString);
    final iv = enc.IV.fromSecureRandom(16); // Creates a random salt
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final encrypted = encrypter.encryptBytes(fileBytes, iv: iv);
    
    return {
      'encryptedBytes': encrypted.bytes,
      'iv': iv.base64,
    };
  }

  /// 3. THE MISSING MATH: Shred the Key into 5 Shards using SSS
  List<String> shredAesKey(String aesKeyString) {
    // Convert the 32-character string into a massive mathematical integer (BigInt)
    String hexKey = aesKeyString.codeUnits.map((c) => c.toRadixString(16).padLeft(2, '0')).join();
    BigInt secret = BigInt.parse(hexKey, radix: 16);

    // Threshold is 3, so our polynomial degree is 2. We need 2 random coefficients.
    BigInt c1 = _generateRandomBigInt();
    BigInt c2 = _generateRandomBigInt();

    List<String> shards = [];
    
    // Calculate Y for X = 1, 2, 3, 4, 5 (These are the 5 shards!)
    for (int x = 1; x <= 5; x++) {
      BigInt bx = BigInt.from(x);
      
      // The Polynomial: y = (secret + c1*x + c2*x^2) % prime
      BigInt y = (secret + (c1 * bx) + (c2 * bx.pow(2))) % _prime;
      
      // Save it as a coordinate: "X-Y"
      shards.add("$x-${y.toRadixString(16)}");
    }
    
    return shards;
  }

  // =================================================================
  // 🔓 PHASE 2: THE DOWNLOAD PIPELINE (Rebuild & Decrypt)
  // =================================================================

  /// 4. Rebuild the AES Key from 3+ Shards (Lagrange Interpolation)
  String rebuildAesKey(List<String> shards) {
    Map<BigInt, BigInt> points = {};
    
    // Convert the "X-Y" string coordinates back into real numbers
    for (var s in shards) {
      var parts = s.split('-');
      points[BigInt.from(int.parse(parts[0]))] = BigInt.parse(parts[1], radix: 16);
    }

    BigInt secret = BigInt.zero;
    var xCoords = points.keys.toList();

    // Reconstruct the Y-intercept (which is our secret key)
    for (var j in xCoords) {
      BigInt upper = BigInt.one;
      BigInt lower = BigInt.one;

      for (var m in xCoords) {
        if (j == m) continue;
        upper = (upper * (BigInt.zero - m)) % _prime;
        lower = (lower * (j - m)) % _prime;
      }

      BigInt delta = (points[j]! * upper * lower.modInverse(_prime)) % _prime;
      secret = (secret + delta) % _prime;
    }

    // Convert the massive integer back into our 32-character AES string
    String hex = (secret % _prime).toRadixString(16);
    if (hex.length % 2 != 0) hex = '0$hex';
    List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return String.fromCharCodes(bytes);
  }

  /// 5. Decrypt the Scrambled Bytes back into a PDF/Image
  Uint8List decryptHeavyFile(Uint8List encryptedBytes, String aesKeyString, String ivBase64) {
    final key = enc.Key.fromUtf8(aesKeyString);
    final iv = enc.IV.fromBase64(ivBase64);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final decrypted = encrypter.decryptBytes(enc.Encrypted(encryptedBytes), iv: iv);
    return Uint8List.fromList(decrypted);
  }

  // Helper function for the math
  BigInt _generateRandomBigInt() {
    final random = Random.secure();
    String hex = '';
    for(int i=0; i<32; i++) {
       hex += random.nextInt(256).toRadixString(16).padLeft(2, '0');
    }
    return BigInt.parse(hex, radix: 16) % _prime;
  }
}