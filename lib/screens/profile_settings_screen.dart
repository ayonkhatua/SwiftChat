import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/database_service.dart';
import 'login_screen.dart';
import '../services/cloudinary_service.dart';
import 'premium_screen.dart'; // 🟢 Premium Page Link

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final DatabaseService _dbService = DatabaseService();
  final User? user = FirebaseAuth.instance.currentUser;
  
  // Edit Mode Variables
  bool _isEditing = false;
  bool _isUpdating = false;
  bool? _isUsernameAvailable;
  bool _isCheckingUsername = false;
  Timer? _debounce;
  int _bioLimit = 50; // Default Free Limit

  @override
  void initState() {
    super.initState();
    _dbService.getUserLimits().then((limits) {
      if(mounted) setState(() => _bioLimit = limits['bioLimit']);
    });
  }

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  
  void _checkUsernameUniqueness(String username, String currentName) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (username.isEmpty || username == currentName) {
      setState(() {
        _isUsernameAvailable = null;
        _isCheckingUsername = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isCheckingUsername = true);
      final result = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();
      
      if (mounted) {
        setState(() {
          _isUsernameAvailable = result.docs.isEmpty;
          _isCheckingUsername = false;
        });
      }
    });
  }

  void _updateProfile(String currentName) async {
    String newName = _nameController.text.trim();
    String newBio = _bioController.text.trim();
    
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Username cannot be empty")));
      return;
    }

    if (_isUsernameAvailable == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please choose a unique username"), backgroundColor: Colors.redAccent)
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      await _dbService.updateUserProfile(newName, newBio, null);
      if (mounted) {
        setState(() {
          _isEditing = false;
          _isUpdating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isUpdating = false);
      }
    }
  }

  void _pickAndUploadImage(String? oldUrl) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Uploading image...")));
      
      // ☁️ Delete old image from Cloudinary if it exists
      if (oldUrl != null && oldUrl.isNotEmpty) {
        await CloudinaryService().deleteFile(oldUrl);
      }
      
      // ☁️ Upload to Cloudinary
      String? url = await CloudinaryService().uploadFile(File(image.path));
      
      if (url != null) {
        // Update Firestore directly
        await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'profile_pic': url});
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text("Profile Upload Failed"),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(label: "Retry", textColor: Colors.white, onPressed: () => _pickAndUploadImage(oldUrl)),
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      
      // 🟢 Background Glow (Premium Theme)
      body: Stack(
        children: [
          Positioned(
            top: -100, right: -100,
            child: Container(
              height: 300, width: 300,
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withOpacity(0.2),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.purpleAccent.withOpacity(0.3), blurRadius: 100, spreadRadius: 20)],
              ),
            ),
          ),
          
          SafeArea(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _dbService.getUserData(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));

                var userData = snapshot.data!.data() as Map<String, dynamic>;
                String name = userData['username'] ?? "User";
                String bio = userData['bio'] ?? "Hey there! I am using SwiftChat.";
                String email = userData['email'] ?? user?.email ?? "";
                String? photoUrl = userData['profile_pic'];
                bool isPremium = userData['isPremium'] == true; // 💎 Check Premium Status

                if (!_isEditing) {
                  _nameController.text = name;
                  _bioController.text = bio;
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                          const Text("Profile & Settings", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: _isUpdating 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.purpleAccent, strokeWidth: 2))
                                : Icon(_isEditing ? Icons.check : Icons.edit, color: Colors.purpleAccent),
                            onPressed: _isUpdating ? null : () {
                              if (_isEditing) {
                                _updateProfile(name);
                              } else {
                                setState(() => _isEditing = true);
                              }
                            },
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 30),

                      // 🟢 1. PROFILE PICTURE WITH PREMIUM GLOW
                      GestureDetector(
                        onTap: () {
                          if (photoUrl != null) {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => FullScreenProfileViewer(
                                        url: photoUrl, userId: user!.uid)));
                          } else {
                            _pickAndUploadImage(photoUrl);
                          }
                        },
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                // 💎 GOLD BORDER FOR PREMIUM
                                border: isPremium ? Border.all(color: Colors.amber, width: 3) : null,
                                boxShadow: isPremium ? [
                                  BoxShadow(color: Colors.amber.withOpacity(0.6), blurRadius: 20, spreadRadius: 5)
                                ] : [],
                              ),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.grey[900],
                                backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                                child: photoUrl == null ? const Icon(Icons.person, size: 60, color: Colors.white) : null,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Colors.purpleAccent, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 🟢 2. NAME & BADGE
                      _isEditing
                        ? TextField(
                            controller: _nameController,
                            onChanged: (val) => _checkUsernameUniqueness(val, name),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 22),
                            decoration: InputDecoration(
                              border: InputBorder.none, 
                              hintText: "Enter Name", 
                              hintStyle: const TextStyle(color: Colors.grey),
                              suffixIcon: _isCheckingUsername 
                                ? const SizedBox(width: 20, height: 20, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent)))
                                : (_isUsernameAvailable != null 
                                    ? Icon(
                                        _isUsernameAvailable! ? Icons.check_circle : Icons.cancel, 
                                        color: _isUsernameAvailable! ? Colors.green : Colors.redAccent,
                                        size: 20,
                                      ) 
                                    : null),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                              if (isPremium) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.verified, color: Colors.amber, size: 24), // 💎 GOLD TICK
                              ]
                            ],
                          ),
                      
                      Text(email, style: const TextStyle(color: Colors.grey)),

                      const SizedBox(height: 15),

                      // 🟢 BIO SECTION
                      _isEditing
                          ? TextField(
                              controller: _bioController,
                              textAlign: TextAlign.center,
                              maxLength: _bioLimit, // 🟢 Enforce Limit
                              maxLines: 2,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                              decoration: const InputDecoration(border: InputBorder.none, hintText: "Enter Bio", hintStyle: TextStyle(color: Colors.grey)),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: Text(bio, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            ),

                      const SizedBox(height: 30),

                      // 🟢 3. PREMIUM STATUS CARD
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          gradient: isPremium 
                            ? const LinearGradient(colors: [Colors.orange, Colors.amber]) // Gold Gradient
                            : LinearGradient(colors: [Colors.grey[900]!, Colors.grey[800]!]), // Dark Gradient
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.workspace_premium, color: isPremium ? Colors.black : Colors.amber, size: 40),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isPremium ? "SwiftChat Gold Member" : "Free Plan",
                                    style: TextStyle(color: isPremium ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    isPremium ? "All features unlocked 🚀" : "Upgrade to unlock limits",
                                    style: TextStyle(color: isPremium ? Colors.black87 : Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            if (!isPremium)
                              ElevatedButton(
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen())),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                                child: const Text("UPGRADE"),
                              )
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // 🟢 4. SETTINGS LIST (Glass UI)
                      _buildSettingsTile(Icons.privacy_tip, "Privacy & Security", "Ghost Mode, Block List"),
                      _buildSettingsTile(Icons.palette, "Appearance", "Wallpapers, Themes (Premium)", isLocked: !isPremium),
                      _buildSettingsTile(Icons.notifications, "Notifications", "Sounds, Vibrations"),
                      _buildSettingsTile(Icons.help, "Help & Support", "Contact Admin"),
                      
                      const SizedBox(height: 20),
                      
                      // Logout Button
                      ListTile(
                        onTap: () async {
                          await FirebaseAuth.instance.signOut();
                          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                        },
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.logout, color: Colors.redAccent),
                        ),
                        title: const Text("Log Out", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, {bool isLocked = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: isLocked 
          ? const Icon(Icons.lock, color: Colors.grey, size: 20) 
          : const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
      ),
    );
  }
}

// 🟢 NEW: Full Screen Profile Viewer with Remove Option
class FullScreenProfileViewer extends StatelessWidget {
  final String url;
  final String userId;
  const FullScreenProfileViewer({super.key, required this.url, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'remove') {
                // 1. Delete from Cloudinary
                await CloudinaryService().deleteFile(url);
                // 2. Update Firestore
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .update({'profile_pic': null});
                if (context.mounted) Navigator.pop(context);
              } else if (value == 'change') {
                Navigator.pop(context);
                // Trigger image pick logic could be added here or handled in main screen
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'remove',
                  child: Text("Remove Profile Photo",
                      style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: url,
            placeholder: (context, url) => const CircularProgressIndicator(color: Colors.purpleAccent),
          ),
        ),
      ),
    );
  }
}