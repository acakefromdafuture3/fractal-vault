import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CloudDispatcher {
  
  // ==========================================
  // 🛡️ NODE 1: SUPABASE CREDENTIALS
  // ==========================================
  final String _supabaseUrl = "https://uoxanidegimtnlmehjkn.supabase.co";
  final String _supabaseSecretKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVveGFuaWRlZ2ltdG5sbWVoamtuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTM5NTQwOSwiZXhwIjoyMDkwOTcxNDA5fQ.c_hJ2P8sE19pxxqjvzsm-IJ-TbeZBdOs6iKC3hpKSxo"; // <-- Put your real key back here!
  final String _supabaseBucket = "shard-node-1"; 

  // ==========================================
  // 🛡️ NODE 2: APPWRITE CREDENTIALS
  // ==========================================
  final String _appwriteEndpoint = "https://sgp.cloud.appwrite.io/v1";
  final String _appwriteProject = "69d27d40001e99cd0261";
  final String _appwriteKey = "standard_1ba11f25aca41b8b0071444b0fd6451d3a0df292daddcec20a2b20f178915db4818f44d5a7a0e04fbfc475b25b463cd9e31b98e81b321fc7519a776a8ccc85ff53a180aeb36f2ccb5277f405bd4c60a173a4e91392dffbf0fe6a69d6d6f3d49de47ded5bf1c538a5a262bf75dfecf09bb7207767d54add8e308ed9e0eb0ab776";
  final String _appwriteBucket = "69d27d7000227e7367d9"; 


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