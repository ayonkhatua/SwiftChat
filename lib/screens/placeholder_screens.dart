import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/database_service.dart';

// ---------------------------------------------------------------------------
// 🟢 CREATE GROUP SCREEN (Real Implementation)
// ---------------------------------------------------------------------------
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  _CreateGroupScreenState createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _nameController = TextEditingController();
  
  final List<String> _selectedUserIds = []; // Jo log select hue
  XFile? _groupImage;
  bool _isLoading = false;

  void _createGroup() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a group name")));
      return;
    }
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least 1 friend")));
      return;
    }

    setState(() => _isLoading = true);
    
    await _dbService.createGroup(
      _nameController.text.trim(),
      _groupImage,
      _selectedUserIds
    );

    setState(() => _isLoading = false);
    Navigator.pop(context); // Wapas Home par jao
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Group Created Successfully! 🎉")));
  }

  void _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _groupImage = image);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("New Group", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createGroup, 
            child: Text("CREATE", style: TextStyle(color: _isLoading ? Colors.grey : Colors.purpleAccent, fontWeight: FontWeight.bold))
          )
        ],
      ),
      body: Column(
        children: [
          // 1. Group Info Section (Top)
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.grey[900],
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: _groupImage != null ? FileImage(File(_groupImage!.path)) : null,
                    child: _groupImage == null ? const Icon(Icons.camera_alt, color: Colors.white) : null,
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
              child: Text("Select Participants", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold))
            ),
          ),

          // 2. Friends Selection List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _dbService.getMyFriends(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                
                var friends = snapshot.data!;
                if (friends.isEmpty) {
                  return const Center(child: Text("No friends found.\nAdd friends from Search first!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    var user = friends[index];
                    String uid = user['uid'];
                    String name = user['username'] ?? "Unknown";
                    String? photo = user['profile_pic'];
                    bool isSelected = _selectedUserIds.contains(uid);

                    return ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundImage: photo != null ? CachedNetworkImageProvider(photo) : null,
                            backgroundColor: Colors.grey[800],
                            child: photo == null ? const Icon(Icons.person, color: Colors.white) : null,
                          ),
                          if (isSelected)
                            const Positioned(
                              bottom: 0, right: 0,
                              child: CircleAvatar(radius: 10, backgroundColor: Colors.purpleAccent, child: Icon(Icons.check, size: 12, color: Colors.white)),
                            )
                        ],
                      ),
                      title: Text(name, style: const TextStyle(color: Colors.white)),
                      trailing: Checkbox(
                        value: isSelected,
                        activeColor: Colors.purpleAccent,
                        checkColor: Colors.white,
                        side: const BorderSide(color: Colors.grey),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedUserIds.add(uid);
                            } else {
                              _selectedUserIds.remove(uid);
                            }
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedUserIds.remove(uid);
                          } else {
                            _selectedUserIds.add(uid);
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

// ---------------------------------------------------------------------------
// 🟡 PLACEHOLDERS (Channel & Settings Abhi bhi dummy hain)
// ---------------------------------------------------------------------------
class CreateChannelScreen extends StatelessWidget {
  const CreateChannelScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("New Channel", style: TextStyle(color: Colors.white)), backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: const Center(child: Text("Channel Feature Coming Soon!", style: TextStyle(color: Colors.white))),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Settings", style: TextStyle(color: Colors.white)), backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: const Center(child: Text("Settings Feature Coming Soon!", style: TextStyle(color: Colors.white))),
    );
  }
}