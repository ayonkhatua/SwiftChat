import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  _ProfileSettingsScreenState createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  String? _photoUrl;
  bool _isLoading = false;
  XFile? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['username'] ?? "";
          _aboutController.text = data['about'] ?? "Hey there! I am using SwiftChat.";
          _photoUrl = data['profile_pic'];
        });
      }
    }
  }

  void _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFile = image;
      });
    }
  }

  void _saveProfile() async {
    setState(() => _isLoading = true);
    await _dbService.updateUserProfile(_nameController.text, _imageFile); // Note: Update this in DB service to handle 'about' if needed
    
    // Save 'About' separately as updateProfile might not cover it yet
    String uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'about': _aboutController.text,
    });

    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated!")));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 📸 Profile Picture
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 70,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: _imageFile != null
                        ? FileImage(File(_imageFile!.path))
                        : (_photoUrl != null ? CachedNetworkImageProvider(_photoUrl!) : null) as ImageProvider?,
                    child: _imageFile == null && _photoUrl == null
                        ? const Icon(Icons.person, size: 70, color: Colors.white)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 👤 Name Field
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Name",
                labelStyle: TextStyle(color: Colors.purpleAccent),
                prefixIcon: Icon(Icons.person, color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
              ),
            ),
            const SizedBox(height: 20),

            // ℹ️ About Field
            TextField(
              controller: _aboutController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "About",
                labelStyle: TextStyle(color: Colors.purpleAccent),
                prefixIcon: Icon(Icons.info_outline, color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
              ),
            ),
            const SizedBox(height: 20),

            // 📞 Phone (Read Only)
            TextField(
              enabled: false,
              controller: TextEditingController(text: FirebaseAuth.instance.currentUser?.email ?? ""),
              style: const TextStyle(color: Colors.grey),
              decoration: const InputDecoration(
                labelText: "Email",
                labelStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.email, color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 40),

            // 💾 Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("Save Changes", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}