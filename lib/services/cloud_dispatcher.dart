// Location: lib/services/cloud_dispatcher.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart'; 
import 'local_node_manager.dart';

class CloudDispatcher {
  
  // ==========================================
  // 🛡️ PULLING SECRETS FROM .ENV 
  // ==========================================
  final String _supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final String _supabaseSecretKey = dotenv.env['SUPABASE_SERVICE_ROLE'] ?? '';
  final String _supabaseBucket = "shard-node-1"; 

  final String _appwriteEndpoint = dotenv.env['APPWRITE_ENDPOINT'] ?? '';
  final String _appwriteProject = dotenv.env['APPWRITE_PROJECT_ID'] ?? '';
  final String _appwriteKey = dotenv.env['APPWRITE_API_KEY'] ?? '';
  final String _appwriteBucket = dotenv.env['APPWRITE_BUCKET_ID'] ?? ''; 
  final String _cloudinaryCloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  final String _cloudinaryApiKey = dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  final String _cloudinaryApiSecret = dotenv.env['CLOUDINARY_API_SECRET'] ?? '';
  final String _imageKitPrivateKey = dotenv.env['IMAGEKIT_PRIVATE_KEY'] ?? '';

  // =========================================================================
  // 🚀 NODE 1: SUPABASE (File + Shard 0)
  // =========================================================================
  Future<bool> uploadToSupabase({required String fileId, required Uint8List fileBytes, required String keyShard}) async {
    final String fileUrl = "$_supabaseUrl/storage/v1/object/$_supabaseBucket/$fileId.bin";
    final String shardUrl = "$_supabaseUrl/storage/v1/object/$_supabaseBucket/$fileId-key.txt";

    try {
      // 1. Upload the Heavy File
      await http.post(Uri.parse(fileUrl), headers: {"Authorization": "Bearer $_supabaseSecretKey", "Content-Type": "application/octet-stream"}, body: fileBytes);
      
      // 2. Upload the Tiny Key Shard
      final shardRes = await http.post(Uri.parse(shardUrl), headers: {"Authorization": "Bearer $_supabaseSecretKey", "Content-Type": "text/plain"}, body: keyShard);

      return shardRes.statusCode == 200;
    } catch (e) { return false; }
  }

  // =========================================================================
  // 🚀 NODE 2: APPWRITE (File + Shard 1)
  // =========================================================================
  Future<bool> uploadToAppwrite({required String fileId, required Uint8List fileBytes, required String keyShard}) async {
    final String apiUrl = "$_appwriteEndpoint/storage/buckets/$_appwriteBucket/files";

    try {
      // Helper for Multipart
      Future<int> sendPart(String id, List<int> bytes, String name) async {
        var req = http.MultipartRequest('POST', Uri.parse(apiUrl));
        req.headers.addAll({'X-Appwrite-Project': _appwriteProject, 'X-Appwrite-Key': _appwriteKey});
        req.fields['fileId'] = id;
        req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: name));
        var res = await req.send();
        return res.statusCode;
      }

      // Upload both
      await sendPart("${fileId}f", fileBytes, "$fileId.bin");
      final shardStatus = await sendPart("${fileId}k", utf8.encode(keyShard), "$fileId-key.txt");

      return shardStatus == 201;
    } catch (e) { return false; }
  }

  // =========================================================================
  // 🚀 NODE 3: CLOUDINARY (File + Shard 2)
  // =========================================================================
  Future<bool> uploadToCloudinary({required String fileId, required Uint8List fileBytes, required String keyShard}) async {
    final String apiUrl = "https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/raw/upload";
    
    Future<int> sendCloudinary(String publicId, List<int> bytes) async {
      int ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      String sig = sha1.convert(utf8.encode("public_id=$publicId&timestamp=$ts$_cloudinaryApiSecret")).toString();
      var req = http.MultipartRequest('POST', Uri.parse(apiUrl));
      req.fields.addAll({'api_key': _cloudinaryApiKey, 'timestamp': ts.toString(), 'signature': sig, 'public_id': publicId});
      req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: publicId));
      var res = await req.send();
      return res.statusCode;
    }

    await sendCloudinary("$fileId.bin", fileBytes);
    final shardStatus = await sendCloudinary("$fileId-key.txt", utf8.encode(keyShard));

    return shardStatus == 200;
  }

  // =========================================================================
  // 🚀 NODE 4: IMAGEKIT (File + Shard 3)
  // =========================================================================
  Future<bool> uploadToImageKit({required String fileId, required Uint8List fileBytes, required String keyShard}) async {
    final String apiUrl = "https://upload.imagekit.io/api/v1/files/upload";
    String auth = 'Basic ${base64Encode(utf8.encode('$_imageKitPrivateKey:'))}';

    Future<int> sendImageKit(String name, List<int> bytes) async {
      var req = http.MultipartRequest('POST', Uri.parse(apiUrl));
      req.headers.addAll({'Authorization': auth});
      req.fields.addAll({'fileName': name, 'useUniqueFileName': 'false'});
      req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: name));
      var res = await req.send();
      return res.statusCode;
    }

    await sendImageKit("$fileId.bin", fileBytes);
    final shardStatus = await sendImageKit("$fileId-key.txt", utf8.encode(keyShard));

    return shardStatus == 200;
  }

  // =========================================================================
  // 🛰️ THE MASTER SCATTER PROTOCOL (The Brain)
  // =========================================================================
  Future<Map<String, String>> disperseToNodes({
    required String fileId, 
    required Uint8List bytes, 
    required String extension,
    required List<String> shards, 
  }) async {
    print("🛰️ INITIALIZING DECENTRALIZED DISPERSION...");

    // Dispatching "Combo Meals" to all nodes simultaneously
    final results = await Future.wait([
      uploadToSupabase(fileId: fileId, fileBytes: bytes, keyShard: shards[0]),
      uploadToAppwrite(fileId: fileId, fileBytes: bytes, keyShard: shards[1]),
      uploadToCloudinary(fileId: fileId, fileBytes: bytes, keyShard: shards[2]),
      uploadToImageKit(fileId: fileId, fileBytes: bytes, keyShard: shards[3]),
    ]);

    // Node 5: Local Storage 
    bool localStatus = false;
    try {
      await LocalNodeManager().securePhysicalKey(fileId: fileId, shardBytes: bytes);
      // We also store the 5th shard locally
      await LocalNodeManager().storeLocalShard(fileId, shards[4]); 
      localStatus = true;
    } catch (e) { print("❌ NODE 5 FAILED: $e"); }

    return {
      'supabase': results[0] ? "active" : "failed",
      'appwrite': results[1] ? "active" : "failed",
      'cloudinary': results[2] ? "active" : "failed",
      'imagekit': results[3] ? "active" : "failed",
      'local': localStatus ? "active" : "failed", 
    };
  }

  // =========================================================================
  // 📥 DOWNLOADER: Reconstructing from Fragments
  // =========================================================================
  
  // 1. Fetch the Encrypted File (Burger)
  Future<Uint8List?> downloadEncryptedFile(String fileId) async {
    final String url = "$_supabaseUrl/storage/v1/object/$_supabaseBucket/$fileId.bin";
    try {
      final res = await http.get(Uri.parse(url), headers: {"Authorization": "Bearer $_supabaseSecretKey"});
      return res.statusCode == 200 ? res.bodyBytes : null;
    } catch (e) { return null; }
  }

  // 🍟 SHARD 0: Fetch from Supabase
  Future<String?> downloadShardFromSupabase(String fileId) async {
    final String url = "$_supabaseUrl/storage/v1/object/$_supabaseBucket/$fileId-key.txt";
    try {
      final res = await http.get(Uri.parse(url), headers: {"Authorization": "Bearer $_supabaseSecretKey"});
      return res.statusCode == 200 ? res.body : null;
    } catch (e) { return null; }
  }

  // 🍟 SHARD 1: Fetch from Appwrite
  Future<String?> downloadShardFromAppwrite(String fileId) async {
    final String fileIdKey = "${fileId}k".replaceAll(RegExp(r'[^a-zA-Z0-9.-]'), '');
    final String url = "$_appwriteEndpoint/storage/buckets/$_appwriteBucket/files/$fileIdKey/view";
    try {
      final res = await http.get(Uri.parse(url), headers: {
        'X-Appwrite-Project': _appwriteProject,
        'X-Appwrite-Key': _appwriteKey,
      });
      return res.statusCode == 200 ? res.body : null;
    } catch (e) { return null; }
  }

  // 🍟 SHARD 2: Fetch from Cloudinary
  Future<String?> downloadShardFromCloudinary(String fileId) async {
    final String cleanId = "${fileId}s3".replaceAll(RegExp(r'[^a-zA-Z0-9.-]'), '');
    final String url = "https://res.cloudinary.com/$_cloudinaryCloudName/raw/upload/v1/$cleanId.txt";
    try {
      final res = await http.get(Uri.parse(url));
      return res.statusCode == 200 ? res.body : null;
    } catch (e) { return null; }
  }

  // 🍟 SHARD 3: Fetch from ImageKit
  Future<String?> downloadShardFromImageKit(String fileId) async {
    final String cleanId = "${fileId}s4".replaceAll(RegExp(r'[^a-zA-Z0-9.-]'), '');
    // Note: Assuming standard ImageKit endpoint. Update if you have a custom domain.
    final String url = "https://ik.imagekit.io/$_cloudinaryCloudName/$cleanId.txt"; 
    try {
      final res = await http.get(Uri.parse(url));
      return res.statusCode == 200 ? res.body : null;
    } catch (e) { return null; }
  }

  // 🍟 SHARD 4: Fetch from Local Hardware
  Future<String?> downloadShardFromLocal(String fileId) async {
    try {
      return await LocalNodeManager().getLocalShard(fileId);
    } catch (e) { return null; }
  }
}