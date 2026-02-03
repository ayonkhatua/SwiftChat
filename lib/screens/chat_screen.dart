import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 🟢 FIX: Uncommented (Required for Channel Logic)
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/database_service.dart';
import '../models/message_model.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final bool isGroup; 

  const ChatScreen({
    super.key, 
    required this.receiverId, 
    required this.receiverName,
    this.isGroup = false, 
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  final ScrollController _scrollController = ScrollController();
  
  bool _isTyping = false;
  String? _wallpaperImage;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isGroup) _checkBlockStatus();
    _dbService.markMessagesAsRead(widget.receiverId);
    
    _messageController.addListener(() {
      setState(() {
        _isTyping = _messageController.text.isNotEmpty;
      });
      if (!widget.isGroup) {
        _dbService.setTypingStatus(widget.receiverId, _isTyping);
      }
    });
  }

  void _checkBlockStatus() {
    _dbService.isUserBlocked(widget.receiverId).listen((isBlocked) {
      if(mounted) setState(() => _isBlocked = isBlocked);
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    if (!widget.isGroup) {
      bool amIBlocked = await _dbService.amIBlockedBy(widget.receiverId);
      if (amIBlocked) {
        _showSnack("You cannot send messages to this user.");
        return;
      }
      if (_isBlocked) {
        _showSnack("Unblock this user to send messages.");
        return;
      }
    }

    await _dbService.sendMessage(
      widget.receiverId, 
      _messageController.text.trim(), 
      widget.receiverName,
      isGroup: widget.isGroup 
    );
    
    _messageController.clear();
    _scrollToBottom();
  }

  void _sendImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _dbService.sendImageMessage(
        widget.receiverId, 
        image, 
        widget.receiverName, 
      ); 
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), 
      backgroundColor: Colors.redAccent
    ));
  }

  void _handleMenuOption(String value) {
    switch (value) {
      case 'view_profile':
        _showSnack("Profile View Coming Soon");
        break;
      case 'wallpaper':
        _pickWallpaper();
        break;
      case 'mute':
        _showSnack("Notifications Muted");
        break;
      case 'block':
        _toggleBlockUser();
        break;
    }
  }

  void _toggleBlockUser() async {
    if (_isBlocked) {
      await _dbService.unblockUser(widget.receiverId);
      _showSnack("User Unblocked");
    } else {
      await _dbService.blockUser(widget.receiverId);
      _showSnack("User Blocked");
    }
  }

  void _pickWallpaper() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _wallpaperImage = image.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leadingWidth: 40, 
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: widget.isGroup ? const Color(0xFF6A11CB) : Colors.purpleAccent,
              child: widget.isGroup 
                ? const Icon(Icons.groups, size: 20, color: Colors.white)
                : Text(widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : "?", 
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.receiverName, 
                    style: const TextStyle(fontSize: 16, color: Colors.white, overflow: TextOverflow.ellipsis, fontWeight: FontWeight.w600)
                  ),
                  if (!widget.isGroup)
                    StreamBuilder<bool>(
                      stream: _dbService.getTypingStatus(widget.receiverId),
                      builder: (context, snapshot) {
                        if (snapshot.data == true) {
                          return const Text("Typing...", style: TextStyle(fontSize: 12, color: Color(0xFF2575FC)));
                        }
                        return const SizedBox(); 
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam_rounded, color: Color(0xFF6A11CB)), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call_rounded, color: Color(0xFF6A11CB)), onPressed: () {}),
          
          PopupMenuButton<String>(
            onSelected: _handleMenuOption,
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF1E1E1E),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'view_profile', child: Text("View Profile", style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'wallpaper', child: Text("Wallpaper", style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'mute', child: Text("Mute Notification", style: TextStyle(color: Colors.white))),
              
              if (!widget.isGroup)
                PopupMenuItem(
                  value: 'block', 
                  child: Text(_isBlocked ? "Unblock User" : "Block User", style: TextStyle(color: _isBlocked ? Colors.green : Colors.redAccent))
                ),
            ],
          ),
        ],
      ),

      body: Container(
        decoration: _wallpaperImage != null 
          ? BoxDecoration(
              image: DecorationImage(
                image: FileImage(File(_wallpaperImage!)), 
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken) 
              )
            )
          : null,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: _dbService.getMessages(widget.receiverId, isGroup: widget.isGroup),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB)));

                  var messages = snapshot.data!;
                  
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      var msg = messages[index];
                      bool isMe = msg.senderId == FirebaseAuth.instance.currentUser!.uid;
                      
                      DateTime dt = msg.timestamp.toDate();
                      String timeString = "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: isMe 
                              ? const LinearGradient(
                                  colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ) 
                              : null,
                            color: isMe ? null : const Color(0xFF2C2C2C),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4), 
                              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.isGroup && !isMe)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4.0),
                                  child: Text(
                                    msg.senderName ?? "Member",
                                    style: TextStyle(color: Colors.purpleAccent[100], fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),

                              msg.type == 'image'
                                ? GestureDetector(
                                    onTap: () {},
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: msg.text, 
                                        height: 200, 
                                        width: 200, 
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(color: Colors.black12, height: 200, width: 200),
                                        errorWidget: (context, url, error) => const Icon(Icons.error),
                                      ),
                                    ),
                                  )
                                : Text(
                                    msg.text, 
                                    style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.3),
                                  ),
                              
                              const SizedBox(height: 4),
                              
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    timeString, 
                                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
                                  ),
                                  if(isMe) ...[
                                    const SizedBox(width: 5),
                                    Icon(
                                      Icons.done_all, 
                                      size: 14, 
                                      color: msg.isRead ? Colors.white : Colors.white54
                                    )
                                  ]
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // 🟢 Input Area Logic with Channel Restrictions
            _isBlocked 
              ? Container(
                  padding: const EdgeInsets.all(15),
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: const Text("You blocked this user. Tap menu to unblock.", style: TextStyle(color: Colors.redAccent)),
                )
              : StreamBuilder<DocumentSnapshot>(
                  // Sirf Group/Channel ke liye live data check karo
                  stream: widget.isGroup 
                      ? FirebaseFirestore.instance.collection('chats').doc(widget.receiverId).snapshots()
                      : null, // Personal chat ke liye null (default allow)
                  builder: (context, snapshot) {
                      bool canSendMessage = true;
                      String restrictionText = "";

                      // Agar Group/Channel hai, to permissions check karo
                      if (widget.isGroup && snapshot.hasData && snapshot.data!.exists) {
                          var data = snapshot.data!.data() as Map<String, dynamic>;
                          bool isChannel = data['isChannel'] ?? false;
                          String adminId = data['adminId'];
                          String currentId = FirebaseAuth.instance.currentUser!.uid;

                          // 🛑 RESTRICTION: Agar Channel hai aur user Admin nahi hai
                          if (isChannel && currentId != adminId) {
                              canSendMessage = false;
                              restrictionText = "Only Admin can post here";
                          }
                      }

                      // Agar Restricted hai, to Error Message dikhao
                      if (!canSendMessage) {
                          return Container(
                              padding: const EdgeInsets.all(15),
                              color: const Color(0xFF121212),
                              alignment: Alignment.center,
                              child: Text(
                                restrictionText.toUpperCase(), 
                                style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.2)
                              ),
                          );
                      }

                      // Normal Input Field
                      return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          color: const Color(0xFF121212),
                          child: Row(
                              children: [
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF6A11CB)), 
                                    onPressed: () {}
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _messageController,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        hintText: "Message...",
                                        hintStyle: const TextStyle(color: Colors.grey),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                                        filled: true,
                                        fillColor: const Color(0xFF2C2C2C),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                        suffixIcon: IconButton(
                                          icon: const Icon(Icons.camera_alt_outlined, color: Colors.grey), 
                                          onPressed: _sendImage
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFF6A11CB),
                                    radius: 24,
                                    child: IconButton(
                                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                      onPressed: _sendMessage,
                                    ),
                                  ),
                              ],
                          ),
                      );
                  }
              ),
          ],
        ),
      ),
    );
  }
}