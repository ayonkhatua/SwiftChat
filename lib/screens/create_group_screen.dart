import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../services/database_service.dart';
import '../services/cloudinary_service.dart';
import 'premium_screen.dart'; // 🟢 Premium Screen Import kiya

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  
  final List<String> _selectedUserIds = [];
  XFile? _groupIcon;
  bool _isLoading = false;

  // Image Picker
  void _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _groupIcon = image);
  }

  // 🟢 MAIN LOGIC: Create Group & Check Premium
  void _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter group name")));
      return;
    }
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least 1 member")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Upload Icon to Cloudinary (if selected)
      String? iconUrl;
      if (_groupIcon != null) {
        iconUrl = await CloudinaryService().uploadFile(File(_groupIcon!.path));
      }

      // 2. Create Group in Firestore Directly
      DocumentReference groupRef = FirebaseFirestore.instance.collection('chats').doc();
      
      List<String> participants = [user.uid, ..._selectedUserIds];
      
      await groupRef.set({
        'groupName': _nameController.text.trim(),
        'groupIcon': iconUrl,
        'isGroup': true,
        'adminId': user.uid,
        'participants': participants,
        'recentUpdated': FieldValue.serverTimestamp(),
        'lastMessage': "Group Created",
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdBy': user.displayName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Success
      if(mounted) {
        Navigator.pop(context); // Screen band karo
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Group Created Successfully!")));
      }

    } catch (e) {
      // 🛑 ERROR HANDLING: Agar Limit Cross hui
      if (e.toString().contains("MEMBERS_LIMIT_EXCEEDED")) {
        // 🔥 Premium Screen Kholo
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("New Group", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _createGroup,
        backgroundColor: const Color(0xFF6A11CB),
        icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check),
        label: Text("Create (${_selectedUserIds.length})"),
      ),
      body: Column(
        children: [
          // 1. Group Info Section
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF1E1E1E),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: _groupIcon != null ? FileImage(File(_groupIcon!.path)) : null,
                    child: _groupIcon == null ? const Icon(Icons.camera_alt, color: Colors.white) : null,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Group Subject",
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.all(15.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Select Participants", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
            ),
          ),

          // 2. Friends List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _dbService.getMyFriends(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                var friends = snapshot.data!;
                if (friends.isEmpty) {
                  return const Center(child: Text("No friends found. Add friends first!", style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    var friend = friends[index];
                    String uid = friend['uid'];
                    String name = friend['username'] ?? "Unknown";
                    bool isSelected = _selectedUserIds.contains(uid);

                    return CheckboxListTile(
                      value: isSelected,
                      activeColor: const Color(0xFF6A11CB),
                      checkColor: Colors.white,
                      title: Text(name, style: const TextStyle(color: Colors.white)),
                      secondary: CircleAvatar(
                        backgroundColor: Colors.grey[800],
                        backgroundImage: friend['profile_pic'] != null ? NetworkImage(friend['profile_pic']) : null,
                        child: friend['profile_pic'] == null ? Text(name[0]) : null,
                      ),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedUserIds.add(uid);
                          } else {
                            _selectedUserIds.remove(uid);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}