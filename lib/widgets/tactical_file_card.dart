// Location: lib/widgets/tactical_file_card.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TacticalFileCard extends StatelessWidget {
  final Map<String, dynamic> file;
  final ColorScheme colors;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const TacticalFileCard({
    super.key,
    required this.file,
    required this.colors,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  IconData _getFileIcon(String type) {
    switch (type) {
      case 'image': return Icons.image;
      case 'document': return Icons.picture_as_pdf;
      case 'text': return Icons.text_snippet;
      case 'audio': return Icons.audiotrack;
      case 'video': return Icons.movie;
      default: return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    String addedDate = "00:00:00"; 
    
    if (file['dateAdded'] != null && file['dateAdded'] is Timestamp) {
        addedDate = (file['dateAdded'] as Timestamp).toDate().toString().split('.')[0]; 
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque, 
      onLongPress: onLongPress,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF90CAFF).withOpacity(0.15) : const Color(0xFF0D2137).withOpacity(0.6),
          borderRadius: BorderRadius.circular(10), 
          border: Border.all(
            color: isSelected ? const Color(0xFF90CAFF) : Colors.white.withOpacity(0.08), 
            width: 1
          ),
        ),
        child: Row(
          children: [
            if (isSelectionMode)
              Container(
                margin: const EdgeInsets.only(right: 16),
                width: 24, height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: isSelected ? const Color(0xFF90CAFF) : Colors.white54, width: 2),
                  color: isSelected ? const Color(0xFF90CAFF) : Colors.transparent,
                ),
                child: isSelected ? const Icon(Icons.check, size: 16, color: Color(0xFF0D2137)) : null,
              )
            else
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8), 
                ),
                child: Icon(_getFileIcon(file['type'] ?? ''), color: const Color(0xFF90CAFF), size: 24),
              ),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file['name'] ?? "UNKNOWN_ARTIFACT", 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis, 
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "LOG: $addedDate  |  STAT: ${file['status']?.toUpperCase() ?? 'SECURED'}", 
                    style: TextStyle(
                      color: const Color(0xFF90CAFF).withOpacity(0.7), 
                      fontSize: 10, 
                      fontWeight: FontWeight.w600, 
                      fontFamily: 'Courier', 
                      letterSpacing: 1.0
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}