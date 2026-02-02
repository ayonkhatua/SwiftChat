import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  _ChatScreenState createState() => _ChatScreenState();
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
    if (_messageController.text.isEmpty) return;
    
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
      _messageController.text, 
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
      await _dbService.sendImageMessage(widget.receiverId, image, widget.receiverName);
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  void _handleMenuOption(String value) {
    switch (value) {
      case 'view_profile':
        showDialog(context: context, builder: (_) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(widget.receiverName, style: const TextStyle(color: Colors.white)),
          content: const Text("Profile view logic here", style: TextStyle(color: Colors.white70)),
        ));
        break;
      case 'wallpaper':
        _pickWallpaper();
        break;
      case 'mute':
        _showSnack("Notifications Muted");
        break;
      case 'export':
        _showSnack("Chat Exported");
        break;
      case 'clear':
        _showSnack("Clear chat coming soon");
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
        backgroundColor: Colors.grey[900],
        leadingWidth: 30,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.purpleAccent,
              child: widget.isGroup 
                ? const Icon(Icons.group, size: 20, color: Colors.white)
                : Text(widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.receiverName, style: const TextStyle(fontSize: 16, color: Colors.white)),
                  if (!widget.isGroup)
                    StreamBuilder<bool>(
                      stream: _dbService.getTypingStatus(widget.receiverId),
                      builder: (context, snapshot) {
                        if (snapshot.data == true) {
                          return const Text("Typing...", style: TextStyle(fontSize: 12, color: Colors.purpleAccent));
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
          IconButton(icon: const Icon(Icons.videocam, color: Colors.purpleAccent), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call, color: Colors.purpleAccent), onPressed: () {}),
          
          PopupMenuButton<String>(
            onSelected: _handleMenuOption,
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: Colors.grey[850],
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'view_profile', child: Text("View Profile", style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'wallpaper', child: Text("Wallpaper", style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'mute', child: Text("Mute Notification", style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'export', child: Text("Export Chat", style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'clear', child: Text("Clear Chat", style: TextStyle(color: Colors.white))),
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
          ? BoxDecoration(image: DecorationImage(image: FileImage(File(_wallpaperImage!)), fit: BoxFit.cover))
          : null,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Message>>(
                // 🟢 Updated to use the corrected getMessages function
                stream: _dbService.getMessages(widget.receiverId, isGroup: widget.isGroup),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.white)));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  var messages = snapshot.data!;

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      var msg = messages[index];
                      bool isMe = msg.senderId == FirebaseAuth.instance.currentUser!.uid;
                      
                      // 🟢 FIXED TIMESTAMP ERROR HERE
                      DateTime dt = msg.timestamp.toDate(); 
                      String timeString = "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.purpleAccent.withOpacity(0.8) : Colors.grey[800],
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.isGroup && !isMe)
                                Text(
                                  msg.senderName ?? "Member",
                                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                ),

                              msg.type == 'image'
                                ? CachedNetworkImage(imageUrl: msg.text, height: 200, width: 200, fit: BoxFit.cover)
                                : Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 16)),
                              
                              const SizedBox(height: 5),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    timeString, 
                                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                                  ),
                                  if(isMe) ...[
                                    const SizedBox(width: 5),
                                    Icon(
                                      Icons.done_all, 
                                      size: 14, 
                                      color: msg.isRead ? Colors.blueAccent : Colors.white60
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

            _isBlocked 
              ? Container(
                  padding: const EdgeInsets.all(15),
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: const Text("You blocked this user. Tap menu to unblock.", style: TextStyle(color: Colors.redAccent)),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: Colors.grey[900],
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.add, color: Colors.purpleAccent), onPressed: () {}),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Message...",
                            hintStyle: const TextStyle(color: Colors.grey),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.black,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.grey), 
                              onPressed: _sendImage
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Colors.purpleAccent,
                        radius: 22,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white, size: 20),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}