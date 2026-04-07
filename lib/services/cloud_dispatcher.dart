import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart'; // 🔥 For Cloudinary Signatures
class CloudDispatcher {
  
  // ==========================================
  // 🛡️ PULLING SECRETS FROM .ENV (FORTRESS MODE)
  // ==========================================
  final String _supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final String _supabaseSecretKey = dotenv.env['SUPABASE_SERVICE_ROLE'] ?? '';
  final String _supabaseBucket = "shard-node-1"; 

  final String _appwriteEndpoint = dotenv.env['APPWRITE_ENDPOINT'] ?? '';
  final String _appwriteProject = dotenv.env['APPWRITE_PROJECT_ID'] ?? '';
  final String _appwriteKey = dotenv.env['APPWRITE_API_KEY'] ?? '';
  final String _appwriteBucket = dotenv.env['APPWRITE_BUCKET_ID'] ?? ''; 


  // =========================================================================
  // 🚀 NODE 1 UPLOAD LOGIC (SUPABASE)
  // =========================================================================
  Future<bool> uploadToSupabase({required String fileId, required Uint8List shardBytes}) async {
    print("========================================");
    print("🚀 DISPATCHING SHARD 1 TO SUPABASE...");

    final String apiUrl = "$_supabaseUrl/storage/v1/object/$_supabaseBucket/$fileId-shard1.bin";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Authorization": "Bearer $_supabaseSecretKey",
          "Content-Type": "application/octet-stream", 
        },
        body: shardBytes,
      );

      if (response.statusCode == 200) {
        print("✅ NODE 1 (SUPABASE): UPLOAD SUCCESSFUL!");
        print("========================================");
        return true;
      } else {
        print("❌ NODE 1 FAILED: ${response.statusCode}");
        print("Reason: ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ NODE 1 NETWORK ERROR: $e");
      return false;
    }
  }

  // =========================================================================
  // 🚀 NODE 2 UPLOAD LOGIC (APPWRITE)
  // =========================================================================
  Future<bool> uploadToAppwrite({required String fileId, required Uint8List shardBytes}) async {
    print("========================================");
    print("🚀 DISPATCHING SHARD 2 TO APPWRITE...");

    final String apiUrl = "$_appwriteEndpoint/storage/buckets/$_appwriteBucket/files";

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      
      request.headers.addAll({
        'X-Appwrite-Project': _appwriteProject,
        'X-Appwrite-Key': _appwriteKey,
      });

      // Appwrite file IDs must be max 36 chars and only contain valid characters
      String cleanId = "${fileId}s2".replaceAll(RegExp(r'[^a-zA-Z0-9.-]'), '');
      request.fields['fileId'] = cleanId;

      var multipartFile = http.MultipartFile.fromBytes(
        'file', 
        shardBytes, 
        filename: '$cleanId.bin'
      );
      request.files.add(multipartFile);

      var response = await request.send();

      if (response.statusCode == 201) { 
        print("✅ NODE 2 (APPWRITE): UPLOAD SUCCESSFUL!");
        print("========================================");
        return true;
      } else {
        var responseData = await response.stream.bytesToString();
        print("❌ NODE 2 FAILED: ${response.statusCode}");
        print("Reason: $responseData");
        return false;
      }
    } catch (e) {
      print("❌ NODE 2 NETWORK ERROR: $e");
      return false;
    }
  }
  // ==========================================
  // 🛡️ NODE 3 & 4 SECRETS (From .env)
  // ==========================================
  final String _cloudinaryCloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  final String _cloudinaryApiKey = dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  final String _cloudinaryApiSecret = dotenv.env['CLOUDINARY_API_SECRET'] ?? '';
  
  final String _imageKitPrivateKey = dotenv.env['IMAGEKIT_PRIVATE_KEY'] ?? '';

  // =========================================================================
  // 🚀 NODE 3 UPLOAD LOGIC (CLOUDINARY - THE .TXT OVERRIDE)
  // =========================================================================
  Future<bool> uploadToCloudinary({required String fileId, required Uint8List shardBytes}) async {
    print("========================================");
    print("🚀 DISPATCHING SHARD 3 TO CLOUDINARY (SIGNED)...");

    final String apiUrl = "https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/raw/upload";
    
    int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    String cleanId = "${fileId}s3".replaceAll(RegExp(r'[^a-zA-Z0-9.-]'), '');
    
    // 🔥 THE FIX: We permanently attach .txt to the ID *before* we sign it
    String publicIdWithExt = "$cleanId.txt"; 

    // Build the string to sign (Parameters must be in alphabetical order!)
    String stringToSign = "public_id=$publicIdWithExt&timestamp=$timestamp$_cloudinaryApiSecret";
    String signature = sha1.convert(utf8.encode(stringToSign)).toString();

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      
      request.fields['api_key'] = _cloudinaryApiKey;
      request.fields['timestamp'] = timestamp.toString();
      request.fields['signature'] = signature;
      request.fields['public_id'] = publicIdWithExt; // Send the new ID

      var multipartFile = http.MultipartFile.fromBytes(
        'file', 
        shardBytes, 
        filename: publicIdWithExt // Match the filename
      );
      request.files.add(multipartFile);

      var response = await request.send();

      if (response.statusCode == 200) { 
        print("✅ NODE 3 (CLOUDINARY): UPLOAD SUCCESSFUL!");
        print("========================================");
        return true;
      } else {
        var responseData = await response.stream.bytesToString();
        print("❌ NODE 3 FAILED: ${response.statusCode} | $responseData");
        return false;
      }
    } catch (e) {
      print("❌ NODE 3 NETWORK ERROR: $e");
      return false;
    }
  }

  // =========================================================================
  // 🚀 NODE 4 UPLOAD LOGIC (IMAGEKIT - BASIC AUTH)
  // =========================================================================
  Future<bool> uploadToImageKit({required String fileId, required Uint8List shardBytes}) async {
    print("========================================");
    print("🚀 DISPATCHING SHARD 4 TO IMAGEKIT...");

    final String apiUrl = "https://upload.imagekit.io/api/v1/files/upload";
    
    // ImageKit requires Basic Auth using the Private Key encoded in Base64
    String basicAuth = 'Basic ${base64Encode(utf8.encode('$_imageKitPrivateKey:'))}';
    String cleanId = "${fileId}s4".replaceAll(RegExp(r'[^a-zA-Z0-9.-]'), '');

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.headers.addAll({'Authorization': basicAuth});

      request.fields['fileName'] = '$cleanId.bin';
      request.fields['useUniqueFileName'] = 'false'; 

      var multipartFile = http.MultipartFile.fromBytes('file', shardBytes, filename: '$cleanId.txt');
      request.files.add(multipartFile);

      var response = await request.send();

      if (response.statusCode == 200) { 
        print("✅ NODE 4 (IMAGEKIT): UPLOAD SUCCESSFUL!");
        print("========================================");
        return true;
      } else {
        var responseData = await response.stream.bytesToString();
        print("❌ NODE 4 FAILED: ${response.statusCode} | $responseData");
        return false;
      }
    } catch (e) {
      print("❌ NODE 4 NETWORK ERROR: $e");
      return false;
    }
  }
}