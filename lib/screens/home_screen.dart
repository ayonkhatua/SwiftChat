import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'chat_screen.dart';
import 'login_screen.dart';
import 'profile_settings_screen.dart';
import 'create_group_screen.dart';
import 'premium_screen.dart';
import 'wallet_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final DatabaseService _dbService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  // Pages List
  final List<Widget> _pages = [
    RecentChatsPage(),       
    const SearchPage(),      
    const ProfilePage(),     
  ];

  @override
  void initState() {
    super.initState();
    _dbService.setupPresenceSystem();
    _notificationService.initNotifications();
  }

  void _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context, 
        MaterialPageRoute(builder: (_) => const LoginScreen()), 
        (route) => false
      );
    }
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'profile':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()));
        break;
      case 'group':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
        break;
      // Note: Channel screen agar alag hai to usko import karke use karein, 
      // abhi ke liye group screen hi rakha hai flow maintain karne ke liye.
      case 'channel':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen())); 
        break;
      case 'premium':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
        break;
      case 'logout':
        _handleLogout();
        break;
    }
  }

  // 👻 GHOST MODE PANEL (Sirf Level 2 users access kar payenge UI logic ke through)
  void _showGhostPanel(BuildContext context, Map<String, dynamic> userData) {
    bool hideOnline = userData['ghost_hide_online'] ?? false;
    bool hideSeen = userData['ghost_hide_seen'] ?? false;
    bool hideStoryView = userData['ghost_hide_story_view'] ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                border: Border(top: BorderSide(color: Colors.purpleAccent.withOpacity(0.5), width: 2)),
                boxShadow: [BoxShadow(color: Colors.purpleAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.privacy_tip, color: Colors.purpleAccent, size: 40),
                  const SizedBox(height: 10),
                  const Text("GHOST MODE 👻", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const Text("Ultimate Stealth Features", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 30),

                  _buildGhostSwitch("Freeze Online Status", "Appear offline to everyone.", hideOnline, (val) async {
                    setModalState(() => hideOnline = val);
                    await _dbService.updateGhostSettings('ghost_hide_online', val);
                  }),

                  _buildGhostSwitch("Ninja Seen", "Read messages without blue ticks.", hideSeen, (val) async {
                    setModalState(() => hideSeen = val);
                    await _dbService.updateGhostSettings('ghost_hide_seen', val);
                  }),

                  _buildGhostSwitch("Anonymous Story View", "View stories secretly.", hideStoryView, (val) async {
                    setModalState(() => hideStoryView = val);
                    await _dbService.updateGhostSettings('ghost_hide_story_view', val);
                  }),
                  const SizedBox(height: 20),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildGhostSwitch(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: value ? Colors.purpleAccent : Colors.transparent),
      ),
      child: SwitchListTile(
        activeThumbColor: Colors.purpleAccent,
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Blobs
          Positioned(
            top: -100, left: -50,
            child: Container(
              height: 300, width: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF6A11CB).withOpacity(0.3),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: const Color(0xFF6A11CB).withOpacity(0.4), blurRadius: 100, spreadRadius: 50)],
              ),
            ),
          ),
          Positioned(
            bottom: 100, right: -50,
            child: Container(
              height: 250, width: 250,
              decoration: BoxDecoration(
                color: const Color(0xFF2575FC).withOpacity(0.2),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: const Color(0xFF2575FC).withOpacity(0.3), blurRadius: 100, spreadRadius: 50)],
              ),
            ),
          ),
          
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              
              appBar: _currentIndex == 0 
                ? AppBar(
                    title: const Text("Swift Chat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    actions: [
                      // 🟢 GHOST ICON LOGIC: SIRF 599 PLAN (Level 2) WALO KO DIKHEGA
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          var data = snapshot.data!.data() as Map<String, dynamic>?;
                          
                          // Check Membership Level
                          // 0 = Free, 1 = 99 Plan, 2 = 599 Plan
                          int membershipLevel = data?['membershipLevel'] ?? 0;
                          
                          // Agar Level 2 se kam hai, to icon hide kardo
                          if (membershipLevel < 2) return const SizedBox(); 

                          return IconButton(
                            icon: const Icon(Icons.vpn_key_off_rounded, color: Colors.purpleAccent),
                            onPressed: () => _showGhostPanel(context, data ?? {}),
                          );
                        },
                      ),

                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.white), 
                        onPressed: () => setState(() => _currentIndex = 1)
                      ),
                      
                      PopupMenuButton<String>(
                        onSelected: _onMenuSelected,
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        color: const Color(0xFF1E1E1E),
                        itemBuilder: (BuildContext context) {
                          return [
                            const PopupMenuItem(value: 'profile', child: Row(children: [Icon(Icons.person, color: Colors.purpleAccent), SizedBox(width: 10), Text("Profile", style: TextStyle(color: Colors.white))])),
                            const PopupMenuItem(value: 'group', child: Row(children: [Icon(Icons.group_add, color: Colors.purpleAccent), SizedBox(width: 10), Text("New Group", style: TextStyle(color: Colors.white))])),
                            const PopupMenuItem(value: 'channel', child: Row(children: [Icon(Icons.campaign, color: Colors.purpleAccent), SizedBox(width: 10), Text("New Channel", style: TextStyle(color: Colors.white))])),
                            const PopupMenuItem(value: 'premium', child: Row(children: [Icon(Icons.workspace_premium, color: Colors.amber), SizedBox(width: 10), Text("Premium", style: TextStyle(color: Colors.amber))])),
                            const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, color: Colors.redAccent), SizedBox(width: 10), Text("Logout", style: TextStyle(color: Colors.white))])),
                          ];
                        },
                      ),
                    ],
                  )
                : null,

              body: _pages[_currentIndex],

              bottomNavigationBar: Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white12)),
                  color: Colors.black45,
                ),
                child: BottomNavigationBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  selectedItemColor: const Color(0xFF6A11CB),
                  unselectedItemColor: Colors.grey,
                  currentIndex: _currentIndex,
                  onTap: (index) => setState(() => _currentIndex = index),
                  items: const [
                    BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: "Chats"),
                    BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: "Friends"),
                    BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: "Me"),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// 🟢 TAB 1: RECENT CHATS (WITH VIP ANIMATIONS)
// ---------------------------------------------------------
class RecentChatsPage extends StatelessWidget {
  final DatabaseService _dbService = DatabaseService();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  RecentChatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // STORIES SECTION
        SizedBox(
          height: 100,
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _dbService.getMyFriends(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
              var friends = snapshot.data!;
              
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: friends.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) return _buildMyStory();
                  var friend = friends[index - 1];
                  return _buildStoryItem(friend);
                },
              );
            },
          ),
        ),

        // CHAT LIST
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _dbService.getRecentChats(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                 return const Center(child: Text("Start chatting by adding friends!", style: TextStyle(color: Colors.grey)));
              }

              var docs = snapshot.data!.docs;

              return ListView.builder(
                itemCount: docs.length,
                padding: const EdgeInsets.only(top: 10),
                itemBuilder: (context, index) {
                  var doc = docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  
                  bool isGroup = data['isGroup'] == true;
                  String name = "Unknown";
                  String? image;
                  String chatTargetId; 

                  if (isGroup) {
                    name = data['groupName'] ?? "Group Chat";
                    image = data['groupIcon'];
                    chatTargetId = doc.id;
                  } else {
                    List participants = data['participants'] ?? [];
                    chatTargetId = participants.firstWhere((id) => id != currentUserId, orElse: () => "");
                    if (chatTargetId.isEmpty) return const SizedBox();
                    Map usersMap = data['users'] ?? {};
                    name = usersMap[chatTargetId] ?? "Unknown";
                  }

                  String lastMsg = data['lastMessage'] ?? "";
                  bool isPhoto = lastMsg == "📷 Photo" || (lastMsg.startsWith("http") && lastMsg.contains("firebasestorage"));
                  String displayMsg = isPhoto ? "📷 Photo" : lastMsg;

                  // 🟢 FETCH TARGET USER DATA FOR VIP STYLE
                  return StreamBuilder<DocumentSnapshot>(
                    stream: isGroup ? null : FirebaseFirestore.instance.collection('users').doc(chatTargetId).snapshots(),
                    builder: (context, userSnap) {
                      int membershipLevel = 0; // Default Free
                      
                      if(userSnap.hasData && userSnap.data!.exists) {
                        var userData = userSnap.data!.data() as Map<String, dynamic>;
                        membershipLevel = userData['membershipLevel'] ?? 0;
                        if(!isGroup && userData['profile_pic'] != null) image = userData['profile_pic'];
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                          leading: Stack(
                            children: [
                              // 💎 VIP GLOW BORDER WIDGET
                              VIPAvatarGlow(
                                level: membershipLevel,
                                child: CircleAvatar(
                                  radius: 26,
                                  backgroundColor: isGroup ? const Color(0xFF6A11CB) : const Color(0xFF2575FC),
                                  backgroundImage: image != null ? CachedNetworkImageProvider(image!) : null,
                                  child: image == null 
                                    ? Icon(isGroup ? Icons.groups : Icons.person, color: Colors.white) 
                                    : null,
                                ),
                              ),
                              
                              // Online Status Indicator
                              if (!isGroup)
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: StreamBuilder<DatabaseEvent>(
                                    stream: _dbService.getUserStatus(chatTargetId),
                                    builder: (context, statusSnapshot) {
                                      bool isOnline = false;
                                      if (statusSnapshot.hasData && statusSnapshot.data!.snapshot.value != null) {
                                        var statusData = statusSnapshot.data!.snapshot.value as Map;
                                        isOnline = statusData['state'] == 'online';
                                      }
                                      return Container(
                                        width: 14, height: 14,
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
                          
                          // 👑 VIP ANIMATED NAME WIDGET
                          title: VIPNameWidget(name: name, level: membershipLevel),
                          
                          subtitle: Text(
                            displayMsg, 
                            style: TextStyle(color: isPhoto ? const Color(0xFF6A11CB) : Colors.white60),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => ChatScreen(receiverId: chatTargetId, receiverName: name, isGroup: isGroup),
                            ));
                          },
                        ),
                      );
                    }
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMyStory() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
      child: Column(
        children: [
          Stack(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, color: Colors.white),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.add, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text("My Story", style: TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildStoryItem(Map<String, dynamic> friend) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Colors.purple, Colors.orange]), 
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.black,
              backgroundImage: friend['profile_pic'] != null ? CachedNetworkImageProvider(friend['profile_pic']) : null,
              child: friend['profile_pic'] == null ? Text(friend['username'][0].toUpperCase()) : null,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            friend['username'], 
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// 🟢 TAB 2: SEARCH PAGE (WITH VIP ANIMATIONS)
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
    var res = await _dbService.searchUsersByName(_searchController.text.trim());
    setState(() {
      _searchResults = res;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Search Username...",
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _performSearch(),
        ),
        actions: [IconButton(icon: const Icon(Icons.search, color: Color(0xFF6A11CB)), onPressed: _performSearch)],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB))) 
          : (_searchResults == null || _searchResults!.docs.isEmpty)
              ? const Center(child: Text("Find friends...", style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  itemCount: _searchResults!.docs.length,
                  itemBuilder: (context, index) {
                    var data = _searchResults!.docs[index].data() as Map<String, dynamic>;
                    String uid = _searchResults!.docs[index].id;
                    String name = data['username'] ?? "Unknown";
                    String email = data['email'] ?? "";
                    String? photoUrl = data['profile_pic'];
                    int membershipLevel = data['membershipLevel'] ?? 0;

                    if (uid == FirebaseAuth.instance.currentUser!.uid) return const SizedBox(); 

                    return ListTile(
                      leading: VIPAvatarGlow(
                        level: membershipLevel,
                        child: CircleAvatar(
                          backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                          backgroundColor: Colors.grey[800],
                          child: photoUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                        ),
                      ),
                      
                      // 👑 VIP NAME WIDGET
                      title: VIPNameWidget(name: name, level: membershipLevel),
                      
                      subtitle: Text(email, style: const TextStyle(color: Colors.grey)),
                      trailing: StreamBuilder<String>(
                        stream: _dbService.getFriendshipStatus(uid),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox();
                          String status = snapshot.data!;
                          if (status == "friends") {
                            return IconButton(icon: const Icon(Icons.chat_bubble, color: Color(0xFF6A11CB)), onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(receiverId: uid, receiverName: name)));
                            });
                          }
                          if (status == "request_sent") return const Text("Sent", style: TextStyle(color: Colors.grey));
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A11CB)),
                            onPressed: () => _dbService.sendFriendRequest(uid),
                            child: const Text("Add", style: TextStyle(color: Colors.white)),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

// ---------------------------------------------------------
// 🟢 TAB 3: PROFILE PAGE (WITH VIP EFFECTS)
// ---------------------------------------------------------
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    final DatabaseService dbService = DatabaseService();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text("Profile"), backgroundColor: Colors.transparent),
      body: StreamBuilder<DocumentSnapshot>(
        stream: dbService.getUserData(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var userData = snapshot.data!.data() as Map<String, dynamic>?;
          String name = userData?['username'] ?? "User";
          String? photoUrl = userData?['profile_pic'];
          int membershipLevel = userData?['membershipLevel'] ?? 0;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 💎 LARGE PROFILE GLOW
                VIPAvatarGlow(
                  level: membershipLevel,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[900],
                    backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                    child: photoUrl == null ? const Icon(Icons.person, size: 60, color: Color(0xFF6A11CB)) : null,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 👑 LARGE ANIMATED NAME
                VIPNameWidget(name: name, level: membershipLevel, fontSize: 28),
                
                const SizedBox(height: 10),
                Text(
                  membershipLevel == 2 ? "Ultimate Plan 👑" : (membershipLevel == 1 ? "Golden Plan ⭐" : "Free Plan"),
                  style: TextStyle(color: Colors.grey[400], fontStyle: FontStyle.italic),
                ),
                
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
                  },
                  icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
                  label: const Text("Swift Wallet", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E1E1E), side: const BorderSide(color: Colors.purpleAccent)),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------
// 👑 VIP HELPER WIDGETS (CORE LOGIC FOR ANIMATION)
// -----------------------------------------------------------

class VIPNameWidget extends StatefulWidget {
  final String name;
  final int level; // 0=Free, 1=99(Gold), 2=599(Ultimate)
  final double fontSize;

  const VIPNameWidget({super.key, required this.name, required this.level, this.fontSize = 16});

  @override
  State<VIPNameWidget> createState() => _VIPNameWidgetState();
}

class _VIPNameWidgetState extends State<VIPNameWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 2 Seconds loop for shimmer
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Level 0: Normal White Text
    if (widget.level == 0) {
      return Text(widget.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: widget.fontSize));
    }

    // Level 1: Static Gold (99 Plan)
    if (widget.level == 1) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFC107)],
              begin: Alignment.topLeft, end: Alignment.bottomRight
            ).createShader(bounds),
            child: Text(widget.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: widget.fontSize)),
          ),
          const SizedBox(width: 5),
          Icon(Icons.star_rounded, color: const Color(0xFFFFD700), size: widget.fontSize + 2), 
        ],
      );
    }

    // Level 2: Animated Reflection + Crown (599 Plan)
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  colors: const [Color(0xFFFFD700), Colors.white, Color(0xFFFFD700)], // Gold -> White -> Gold
                  stops: const [0.0, 0.5, 1.0],
                  // Moving the gradient across the text
                  begin: Alignment(-1.0 + (3.0 * _controller.value), -0.5), 
                  end: Alignment(1.0 + (3.0 * _controller.value), 0.5),
                  tileMode: TileMode.clamp,
                ).createShader(bounds);
              },
              child: Text(widget.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: widget.fontSize)),
            );
          },
        ),
        const SizedBox(width: 5),
        Icon(Icons.workspace_premium, color: const Color(0xFFFFD700), size: widget.fontSize + 4), // Crown Badge
      ],
    );
  }
}

class VIPAvatarGlow extends StatelessWidget {
  final int level;
  final Widget child;
  const VIPAvatarGlow({super.key, required this.level, required this.child});

  @override
  Widget build(BuildContext context) {
    // Free User - No Border
    if (level == 0) return child;

    // Premium Users
    return Container(
      padding: const EdgeInsets.all(3), // Border width
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA000)]), // Gold Gradient
        // Level 2 gets Glow Shadow
        boxShadow: level == 2 
            ? [BoxShadow(color: Colors.orangeAccent.withOpacity(0.6), blurRadius: 15, spreadRadius: 2)] 
            : [],
      ),
      child: child,
    );
  }
}