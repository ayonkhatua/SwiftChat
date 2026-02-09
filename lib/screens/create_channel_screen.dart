import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/database_service.dart';

class CreateChannelScreen extends StatefulWidget {
  const CreateChannelScreen({super.key});

  @override
  State<CreateChannelScreen> createState() => _CreateChannelScreenState();
}

class _CreateChannelScreenState extends State<CreateChannelScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  
  XFile? _channelIcon;
  bool _isLoading = false;

  void _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _channelIcon = image);
    }
  }

  void _createChannel() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Channel name is required")));
      return;
    }

    setState(() => _isLoading = true);

    // Channel Logic: Shuru mein sirf Admin member hota hai
    await _dbService.createChannel(
      _nameController.text.trim(),
      _descController.text.trim(),
      _channelIcon
    );

    setState(() => _isLoading = false);
    if(mounted) {
      Navigator.pop(context); // Home par wapas
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Channel Created Successfully! 📢")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("New Channel", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. Channel Icon
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.purpleAccent, width: 2),
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey[900],
                  backgroundImage: _channelIcon != null ? FileImage(File(_channelIcon!.path)) : null,
                  child: _channelIcon == null 
                    ? const Icon(Icons.camera_alt, size: 30, color: Colors.white) 
                    : null,
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 2. Channel Name
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                labelText: "Channel Name",
                labelStyle: const TextStyle(color: Colors.purpleAccent),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.campaign, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 20),

            // 3. Description
            TextField(
              controller: _descController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "Description (Optional)",
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 40),

            // 4. Create Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createChannel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A11CB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Create Channel", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 20),
            const Text(
              "Channels are for broadcasting your messages to an unlimited audience.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            )
          ],
        ),
      ),
    );
  }
}