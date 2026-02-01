import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart'; // 📸 Image Caching
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart'; // 🆕 Edit Profile Screen Import

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final DatabaseService _dbService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  // Pages List for Tabs
  final List<Widget> _pages = [
    RecentChatsPage(),       // 🟢 Tab 1: Recent Chats
    const SearchPage(),      // 🔍 Tab 2: Search Users
    const ProfilePage(),     // 👤 Tab 3: Profile (Updated)
  ];

  @override
  void initState() {
    super.initState();
    // 🚀 Presence System
    _dbService.setupPresenceSystem();
    
    // 🔔 Initialize Notifications
    _notificationService.initNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark Theme
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.purpleAccent, // Neon Accent
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "Chats"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// 🟢 TAB 1: RECENT CHATS PAGE
// ---------------------------------------------------------
class RecentChatsPage extends StatelessWidget {
  final DatabaseService _dbService = DatabaseService();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  RecentChatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Swift Chat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _dbService.getRecentChats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));

          var docs = snapshot.data!.docs;
          if (docs.isEmpty) {
             return const Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.chat_bubble_outline, size: 50, color: Colors.grey),
                   SizedBox(height: 10),
                   Text("No chats yet.\nGo to Search to find friends!", 
                     textAlign: TextAlign.center,
                     style: TextStyle(color: Colors.grey)
                   ),
                 ],
               )
             );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              List participants = data['participants'];
              
              String receiverId = participants.firstWhere((id) => id != currentUserId, orElse: () => "");
              if (receiverId.isEmpty) return const SizedBox();

              String receiverName = data['users']?[receiverId] ?? "Unknown"; 
              
              // 📷 Check if last message was an image
              String lastMsg = data['lastMessage'] ?? "";
              bool isPhoto = lastMsg == "📷 Photo" || (lastMsg.startsWith("http") && lastMsg.contains("firebasestorage"));
              String displayMsg = isPhoto ? "📷 Photo" : lastMsg;

              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.purpleAccent,
                        child: Text(receiverName.isNotEmpty ? receiverName[0].toUpperCase() : "?", 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: StreamBuilder<DatabaseEvent>(
                          stream: _dbService.getUserStatus(receiverId),
                          builder: (context, statusSnapshot) {
                            bool isOnline = false;
                            if (statusSnapshot.hasData && statusSnapshot.data!.snapshot.value != null) {
                              var statusData = statusSnapshot.data!.snapshot.value as Map;
                              isOnline = statusData['state'] == 'online';
                            }
                            return Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: isOnline ? Colors.greenAccent : Colors.grey,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  title: Text(receiverName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    displayMsg, 
                    style: TextStyle(
                      color: isPhoto ? Colors.purpleAccent : Colors.white70, 
                      fontStyle: isPhoto ? FontStyle.italic : FontStyle.normal
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        receiverId: receiverId, 
                        receiverName: receiverName
                      ),
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------
// 🔍 TAB 2: SEARCH PAGE
// ---------------------------------------------------------
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  QuerySnapshot? _searchResults;
  final DatabaseService _dbService = DatabaseService();
  bool _isLoading = false;

  void _performSearch() async {
    if (_searchController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    var res = await _dbService.searchUsers(_searchController.text.trim());
    
    setState(() {
      _searchResults = res;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Search by Email...",
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _performSearch(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.purpleAccent), onPressed: _performSearch)
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)) 
          : (_searchResults == null || _searchResults!.docs.isEmpty)
              ? const Center(child: Text("Search for users to chat", style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  itemCount: _searchResults!.docs.length,
                  itemBuilder: (context, index) {
                    var data = _searchResults!.docs[index].data() as Map<String, dynamic>;
                    String uid = _searchResults!.docs[index].id;
                    String name = data['username'] ?? data['email'];

                    if (uid == FirebaseAuth.instance.currentUser!.uid) return const SizedBox(); 

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[800],
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text(data['email'], style: const TextStyle(color: Colors.grey)),
                      trailing: const Icon(Icons.message, color: Colors.purpleAccent),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ChatScreen(receiverId: uid, receiverName: name),
                        ));
                      },
                    );
                  },
                ),
    );
  }
}

// ---------------------------------------------------------
// 👤 TAB 3: PROFILE PAGE (UPDATED)
// ---------------------------------------------------------
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final DatabaseService dbService = DatabaseService();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          // ⚙️ Edit Button
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.purpleAccent),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
            },
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: dbService.getUserData(), // 📡 Listen to Realtime Data
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));

          var userData = snapshot.data!.data() as Map<String, dynamic>?;
          String name = userData?['username'] ?? "User";
          String email = userData?['email'] ?? "No Email";
          String? photoUrl = userData?['profile_pic'];

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 📸 Profile Pic (Cached)
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[900],
                  backgroundImage: photoUrl != null 
                      ? CachedNetworkImageProvider(photoUrl) 
                      : null,
                  child: photoUrl == null 
                      ? const Icon(Icons.person, size: 60, color: Colors.purpleAccent) 
                      : null,
                ),
                
                const SizedBox(height: 20),
                
                // 👤 Name
                Text(
                  name, 
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)
                ),
                
                const SizedBox(height: 5),
                
                // 📧 Email
                Text(
                  email, 
                  style: const TextStyle(color: Colors.grey, fontSize: 14)
                ),
                
                const SizedBox(height: 40),

                // 🚪 Logout Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: const BorderSide(color: Colors.redAccent)
                    ),
                  ),
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: const Text("Sign Out", style: TextStyle(color: Colors.redAccent)),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                  },
                )
              ],
            ),
          );
        },
      ),
    );
  }
}