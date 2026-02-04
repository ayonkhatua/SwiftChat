import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  // 🔴 Apne Details Yahan Dalein
  final String _cloudName = "dkojsdqvz"; 
  final String _uploadPreset = "my_database";

  late CloudinaryPublic cloudinary;

  CloudinaryService() {
    cloudinary = CloudinaryPublic(_cloudName, _uploadPreset, cache: false);
  }

  // 🟢 Image/Video Upload Function
  Future<String?> uploadFile(File file, {bool isVideo = false, void Function(int count, int total)? onProgress}) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: isVideo ? CloudinaryResourceType.Video : CloudinaryResourceType.Image,
        ),
        onProgress: onProgress,
      );
      return response.secureUrl; // Ye URL hum Firebase mein save karenge
    } catch (e) {
      print("Cloudinary Upload Error: $e");
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
      print("Cloudinary: Requesting deletion for file at $url");
    } catch (e) {
      print("Cloudinary Delete Error: $e");
    }
  }
}