// Location: lib/services/vault_service.dart

class VaultService {
  // Upgraded fake database with 'lastAccessed' and new file types like Audio
  final List<Map<String, dynamic>> _mockFiles = [
    {
      "fileName": "Aadhar_Card.pdf",
      "dateAdded": "2026-04-01",
      "lastAccessed": "2026-04-02",
      "type": "document"
    },
    {
      "fileName": "Emergency_Passphrases.txt",
      "dateAdded": "2026-03-28",
      "lastAccessed": "2026-03-28",
      "type": "text"
    },
    {
      "fileName": "Tista_Valentine_Animation.mp4",
      "dateAdded": "2026-02-14",
      "lastAccessed": "2026-04-01",
      "type": "video"
    },
    {
      "fileName": "Call_Recording_Mom.mp3",
      "dateAdded": "2026-03-10",
      "lastAccessed": "2026-04-03", // Most recent!
      "type": "audio"
    },
    {
      "fileName": "Project_Fractal_Blueprints.png",
      "dateAdded": "2026-03-30",
      "lastAccessed": "2026-03-31",
      "type": "image"
    }
  ];

  // 1. Fetch ALL files (This keeps Tista's current screen working!)
  Future<List<Map<String, dynamic>>> getVaultFiles() async {
    print("System: Decrypting all vault contents...");
    await Future.delayed(const Duration(milliseconds: 1500));
    return _mockFiles;
  }

  // 2. NEW: Fetch ONLY the "Recently Used" files
  Future<List<Map<String, dynamic>>> getRecentFiles() async {
    print("System: Fetching recent files...");
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Create a copy of the list to sort
    List<Map<String, dynamic>> sortedFiles = List.from(_mockFiles);
    
    // Sort them by the 'lastAccessed' date (newest first)
    sortedFiles.sort((a, b) => b['lastAccessed'].compareTo(a['lastAccessed']));
    
    // Return only the top 3 most recent files
    return sortedFiles.take(3).toList();
  }
}