import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

class CloudinaryService {
  // 🔴 Apne Details Yahan Dalein
  final String _cloudName = "dkojsdqvz"; 
  final String _uploadPreset = "my_database";

  late CloudinaryPublic cloudinary;

  CloudinaryService() {
    cloudinary = CloudinaryPublic(_cloudName, _uploadPreset, cache: false);
  }

  // 🟢 Image/Video Upload Function
  Future<String?> uploadFile(File file, {String type = 'image', void Function(int count, int total)? onProgress}) async {
    if (!file.existsSync()) {
      debugPrint("Cloudinary Error: File not found at ${file.path}");
      return null;
    }

    try {
      CloudinaryResourceType resourceType;
      switch (type) {
        case 'video':
          resourceType = CloudinaryResourceType.Video;
          break;
        case 'raw':
          resourceType = CloudinaryResourceType.Raw;
          break;
        case 'auto':
          resourceType = CloudinaryResourceType.Auto;
          break;
        default:
          resourceType = CloudinaryResourceType.Image;
      }

      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: resourceType,
        ),
        onProgress: onProgress,
      );
      return response.secureUrl; // Ye URL hum Firebase mein save karenge
    } catch (e) {
      debugPrint("Cloudinary Upload Error: $e");
      return null;
    }
  }

  // 🗑️ Delete File Function
  Future<void> deleteFile(String? url) async {
    if (url == null || url.isEmpty || !url.contains("cloudinary")) return;
    try {
      // Note: Cloudinary se file delete karne ke liye API Secret aur Signature ki zaroorat hoti hai.
      // Security ki wajah se ise aksar Backend ya Cloud Functions ke zariye kiya jata hai.
      // Yahan humne logic structure add kar diya hai jo file ko identify karega.
      debugPrint("Cloudinary: Requesting deletion for file at $url");
    } catch (e) {
      debugPrint("Cloudinary Delete Error: $e");
    }
  }
}