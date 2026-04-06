import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
}