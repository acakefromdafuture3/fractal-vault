// Location: lib/services/vault_service.dart

class VaultService {
  // A fake database of files stored in the user's vault
  final List<Map<String, String>> _mockFiles = [
    {
      "fileName": "Aadhar_Card.pdf",
      "dateAdded": "2026-04-01",
      "type": "document"
    },
    {
      "fileName": "Emergency_Passphrases.txt",
      "dateAdded": "2026-03-28",
      "type": "text"
    },
    {
      "fileName": "adasd.mp4",
      "dateAdded": "2026-02-14",
      "type": "video"
    },
    {
      "fileName": "Project_Fractal_Blueprints.png",
      "dateAdded": "2026-03-30",
      "type": "image"
    }
  ];

  // The function to fetch the files
  Future<List<Map<String, String>>> getVaultFiles() async {
    print("System: Decrypting vault contents...");
    
    // Simulate a 1.5-second decryption delay
    await Future.delayed(const Duration(milliseconds: 1500));
    
    print("System: Files decrypted successfully.");
    return _mockFiles;
  }
}