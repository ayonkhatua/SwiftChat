import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/database_service.dart';
import 'premium_screen.dart'; // Premium page agar limit cross ho

class ChannelInfoScreen extends StatefulWidget {
  final String chatId;
  const ChannelInfoScreen({super.key, required this.chatId});

  @override
  State<ChannelInfoScreen> createState() => _ChannelInfoScreenState();
}

class _ChannelInfoScreenState extends State<ChannelInfoScreen> {
  final DatabaseService _dbService = DatabaseService();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  // 🟢 MASTER LOGIC: Privacy Toggle Change
  void _toggleHideMembers(bool currentValue, int memberCount, bool isPremium) async {
    bool newValue = !currentValue;

    if (newValue == true) {
      // User HIDE karna chahta hai. Check Conditions:
      
      if (memberCount > 5000) {
        // Condition 1: Bada Channel (5000+) -> Free Allowed
        await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({'hideMembers': true});
      
      } else {
        // Condition 2: Chota Channel (<5000) -> Premium Required
        if (isPremium) {
          await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({'hideMembers': true});
        } else {
          // 🛑 Rokaawat: Premium Screen pheko
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Need 5000+ members or Premium to hide list!")));
        }
      }
    } else {
      // Unhide karna hamesha allowed hai
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({'hideMembers': false});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Channel Info", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (!snapshot.data!.exists) return const Center(child: Text("Channel not found", style: TextStyle(color: Colors.white))); // 🟢 Fix: Doc check

          var data = snapshot.data!.data() as Map<String, dynamic>;
          String name = data['groupName'] ?? "Channel";
          String? icon = data['groupIcon'];
          String desc = data['description'] ?? "No description";
          String adminId = data['adminId'] ?? ""; // 🟢 Fix: Null safety for Admin ID
          List participants = data['participants'] ?? [];
          bool hideMembers = data['hideMembers'] ?? false;
          int memberCount = participants.length;
          
          bool isAdmin = currentUserId == adminId;

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // 1. Channel Icon
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[900],
                  backgroundImage: (icon != null && icon.isNotEmpty) ? CachedNetworkImageProvider(icon) : null, // 🟢 Fix: Empty URL crash fix
                  child: icon == null ? const Icon(Icons.campaign, size: 40, color: Colors.white) : null,
                ),
                const SizedBox(height: 15),
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                Text("$memberCount Subscribers", style: const TextStyle(color: Colors.grey, fontSize: 14)),
                
                const SizedBox(height: 20),
                
                // 2. Description Box
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Description", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(desc, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. ADMIN SETTINGS (Sirf Admin ko dikhega)
                if (isAdmin) ...[
                  FutureBuilder<bool>(
                    future: _dbService.isUserPremium(),
                    builder: (context, premiumSnap) {
                      bool isPremium = premiumSnap.data ?? false;
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.purpleAccent.withOpacity(0.3))
                        ),
                        child: SwitchListTile(
                          activeThumbColor: Colors.purpleAccent,
                          title: const Text("Hide Members List", style: TextStyle(color: Colors.white)),
                          subtitle: Text(
                            memberCount > 5000 ? "Unlocked (Big Channel)" : "Requires Premium or 5k+ members",
                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                          ),
                          value: hideMembers,
                          onChanged: (val) => _toggleHideMembers(hideMembers, memberCount, isPremium),
                        ),
                      );
                    }
                  ),
                  const SizedBox(height: 20),
                ],

                // 4. MEMBER LIST LOGIC
                // Agar Admin hai -> SAB DIKHAO
                // Agar Member hai aur hideMembers ON hai -> MAT DIKHAO
                if (isAdmin || !hideMembers) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Align(alignment: Alignment.centerLeft, child: Text("Subscribers", style: TextStyle(color: Colors.grey))),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: participants.length,
                    itemBuilder: (context, index) {
                      String userId = participants[index];
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                        builder: (context, userSnap) {
                          if (!userSnap.hasData) return const SizedBox();
                          var userData = userSnap.data!.data() as Map<String, dynamic>?;
                          String userName = userData?['username'] ?? "User";
                          bool isThisAdmin = userId == adminId;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey[800],
                              child: Text(userName[0], style: const TextStyle(color: Colors.white)),
                            ),
                            title: Text(userName, style: const TextStyle(color: Colors.white)),
                            trailing: isThisAdmin 
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.purpleAccent, borderRadius: BorderRadius.circular(5)),
                                  child: const Text("Owner", style: TextStyle(color: Colors.white, fontSize: 10))
                                ) 
                              : null,
                          );
                        },
                      );
                    },
                  ),
                ] else ...[
                  // Privacy Mode Message
                  const SizedBox(height: 30),
                  const Icon(Icons.lock, color: Colors.grey, size: 40),
                  const SizedBox(height: 10),
                  const Text("Members list is hidden by Admin", style: TextStyle(color: Colors.grey)),
                ]
              ],
            ),
          );
        },
      ),
    );
  }
}