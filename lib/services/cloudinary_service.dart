import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  // 🔴 Apne Details Yahan Dalein
  final String _cloudName = "YOUR_CLOUD_NAME"; 
  final String _uploadPreset = "YOUR_UPLOAD_PRESET";

  late CloudinaryPublic cloudinary;

  CloudinaryService() {
    cloudinary = CloudinaryPublic(_cloudName, _uploadPreset, cache: false);
  }

  // 🟢 Image/Video Upload Function
  Future<String?> uploadFile(File file, {bool isVideo = false}) async {
    try {
      CloudinaryResponse response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          resourceType: isVideo ? CloudinaryResourceType.Video : CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl; // Ye URL hum Firebase mein save karenge
    } catch (e) {
      print("Cloudinary Upload Error: $e");
      return null;
    }
  }
}