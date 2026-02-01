import 'dart:async'; // ⏱️ Timer
// import 'dart:io'; // ❌ Removed: Web pe error deta hai, XFile use karenge
import 'package:cloud_firestore/cloud_firestore.dart'; // 🟢 Timestamp ke liye
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart'; // 📸 Image Picker
import '../services/database_service.dart';
import '../services/time_service.dart';
import '../models/message_model.dart';
import '../widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatScreen({super.key, required this.receiverId, required this.receiverName});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  final ScrollController _scrollController = ScrollController();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  
  final ImagePicker _picker = ImagePicker();
  Timer? _typingTimer;

  // 🕒 Time Ago Calculator (For Status)
  String _formatTimeAgo(Timestamp timestamp) {
    DateTime time = timestamp.toDate();
    Duration diff = DateTime.now().difference(time);

    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  void _onTextChanged(String value) {
    if (_typingTimer != null) {
      _typingTimer!.cancel();
    }
    _dbService.setTypingStatus(widget.receiverId, true);
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _dbService.setTypingStatus(widget.receiverId, false);
    });
  }

  // 📸 Function to Pick & Send Image (WEB COMPATIBLE FIX)
  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null) {
        // 🟢 FIX: File object mat banao, direct XFile pass karo database service ko
        // File file = File(image.path); // <--- Ye line Web pe crash karti thi
        
        await _dbService.sendImageMessage(widget.receiverId, image, widget.receiverName);
        _scrollToBottom();
      }
    } catch (e) {
      print("Image Pick Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void sendMessage() {
    if (_controller.text.trim().isNotEmpty) {
      _dbService.sendMessage(
        widget.receiverId, 
        _controller.text.trim(),
        widget.receiverName 
      );
      
      _controller.clear();
      _dbService.setTypingStatus(widget.receiverId, false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void showDeleteOptions(Message msg) {
    bool isMyMessage = msg.senderId == currentUserId;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMyMessage)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                  title: const Text('Delete for Everyone', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _dbService.deleteForEveryone(widget.receiverId, msg.id);
                    Navigator.pop(context);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.white),
                title: const Text('Delete for Me', style: TextStyle(color: Colors.white)),
                onTap: () {
                  _dbService.deleteForMe(widget.receiverId, msg.id);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.receiverName, style: const TextStyle(color: Colors.white, fontSize: 18)),
            StreamBuilder<bool>(
              stream: _dbService.getTypingStatus(widget.receiverId),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data == true) {
                  return const Text(
                    "Typing...", 
                    style: TextStyle(color: Colors.purpleAccent, fontSize: 12, fontStyle: FontStyle.italic)
                  );
                }
                return const SizedBox(); 
              },
            ),
          ],
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _dbService.getMessages(widget.receiverId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                var messages = snapshot.data!;
                
                // 🟢 1. MARK AS READ LOGIC
                // Agar chat khuli hai, aur naya message aaya hai jo mera nahi hai, usse Read mark karo
                if (messages.isNotEmpty) {
                  Message lastMsg = messages.last;
                  if (lastMsg.senderId != currentUserId && !lastMsg.isRead) {
                    _dbService.markMessagesAsRead(widget.receiverId);
                  }
                }

                if (messages.isEmpty) return const Center(child: Text("Say Hi! 👋", style: TextStyle(color: Colors.grey)));

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var msg = messages[index];
                    bool isMe = msg.senderId == currentUserId;
                    
                    // 🟢 2. CHECK IF LAST MESSAGE
                    bool isLastMessage = index == messages.length - 1;

                    return GestureDetector(
                      onLongPress: () => showDeleteOptions(msg),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          ChatBubble(
                            text: msg.text, 
                            isMe: isMe,
                            type: msg.type, 
                          ),
                          
                          // 🟢 3. INSTAGRAM STYLE STATUS (Seen/Sent)
                          // Sirf Last Message pe dikhega aur wo message mera hona chahiye
                          if (isMe && isLastMessage)
                            Padding(
                              padding: const EdgeInsets.only(right: 12, bottom: 10, top: 2),
                              child: Text(
                                msg.isRead 
                                    ? "Seen ${_formatTimeAgo(msg.readTimestamp ?? Timestamp.now())}" 
                                    : "Sent ${_formatTimeAgo(msg.timestamp)}",
                                style: const TextStyle(
                                  color: Colors.grey, 
                                  fontSize: 11, 
                                  fontWeight: FontWeight.w500
                                ),
                              ),
                            ),

                          // 🟢 4. Regular Time (Baaki messages ke liye)
                          // Last message pe status dikh raha hai, isliye wahan time nahi dikhayenge
                          if (!isLastMessage)
                             Padding(
                              padding: EdgeInsets.only(left: isMe ? 0 : 15, right: isMe ? 15 : 0, bottom: 5),
                              child: Text(
                                TimeService.formatTime(msg.timestamp), 
                                style: const TextStyle(color: Colors.white24, fontSize: 9)
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: Colors.grey[900],
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image, color: Colors.purpleAccent),
                  onPressed: _pickAndSendImage,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white24)
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _controller,
                      onChanged: _onTextChanged, 
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
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
                    onPressed: sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}