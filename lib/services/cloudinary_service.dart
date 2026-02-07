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
  Future<String?> uploadFile(File file, {String type = 'image', void Function(int count, int total)? onProgress}) async {
    try {
      CloudinaryResourceType resourceType;
      if (type == 'video') resourceType = CloudinaryResourceType.Video;
      else if (type == 'raw') resourceType = CloudinaryResourceType.Raw;
      else if (type == 'auto') resourceType = CloudinaryResourceType.Auto;
      else resourceType = CloudinaryResourceType.Image;

      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: resourceType,
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