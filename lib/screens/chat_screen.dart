import 'dart:io';
import 'dart:ui'; // Glass effect
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:record/record.dart'; // 🎙️ Audio Record
import 'package:audioplayers/audioplayers.dart'; // 🎧 Audio Play
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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
  
  // 🎙️ Audio State
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _currentlyPlayingUrl;
  bool _isPlaying = false;
  
  bool _isTyping = false;
  String? _wallpaperImage;
  bool _isBlocked = false;
  Message? _replyMessage;

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

    // Audio Completion Listener
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _currentlyPlayingUrl = null;
        _isPlaying = false;
      });
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _checkBlockStatus() {
    _dbService.isUserBlocked(widget.receiverId).listen((isBlocked) {
      if(mounted) setState(() => _isBlocked = isBlocked);
    });
  }

  // 🎙️ START RECORDING
  Future<void> _startRecording() async {
    if (await Permission.microphone.request().isGranted) {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String filePath = '${appDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _audioRecorder.start(const RecordConfig(), path: filePath);
      setState(() => _isRecording = true);
    } else {
      _showSnack("Microphone permission required!");
    }
  }

  // 🎙️ STOP & SEND
  Future<void> _stopAndSendRecording() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    
    if (path != null) {
      await _dbService.sendAudioMessage(
        widget.receiverId, 
        path, 
        widget.receiverName, 
        isGroup: widget.isGroup
      );
    }
  }

  Future<void> _cancelRecording() async {
    await _audioRecorder.stop();
    setState(() => _isRecording = false);
  }

  // 🎧 PLAY AUDIO
  Future<void> _playAudio(String url) async {
    if (_currentlyPlayingUrl == url && _isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      setState(() {
        _currentlyPlayingUrl = url;
        _isPlaying = true;
      });
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    
    // Block Logic ...
    if (!widget.isGroup) {
      bool amIBlocked = await _dbService.amIBlockedBy(widget.receiverId);
      if (amIBlocked) { _showSnack("You cannot send messages."); return; }
      if (_isBlocked) { _showSnack("Unblock user first."); return; }
    }

    String text = _messageController.text.trim();
    
    // Reply Logic added to database call
    // (Ideally update database_service to handle replies properly, but keeping consistent with prev code)
    // For now using raw firestore for quick reply support
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    String currentUserName = FirebaseAuth.instance.currentUser!.displayName ?? "User";
    String chatId = widget.isGroup ? widget.receiverId : 
      (currentUserId.compareTo(widget.receiverId) < 0 ? "${currentUserId}_${widget.receiverId}" : "${widget.receiverId}_$currentUserId");

    Map<String, dynamic> msgData = {
      'senderId': currentUserId,
      'senderName': currentUserName,
      'receiverId': widget.receiverId,
      'text': text,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
      'deletedBy': [],
      'isRead': false,
      'reactions': {},
    };

    if (_replyMessage != null) {
      msgData['replyTo'] = {
        'text': _replyMessage!.type == 'image' ? "📷 Photo" : (_replyMessage!.type == 'audio' ? "🎤 Voice Note" : _replyMessage!.text),
        'sender': _replyMessage!.senderName,
        'id': _replyMessage!.messageId ?? "unknown"
      };
    }

    await FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').add(msgData);
    await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
      'lastMessage': text,
      'lastTime': FieldValue.serverTimestamp(),
      if (!widget.isGroup) 'participants': [currentUserId, widget.receiverId],
    }, SetOptions(merge: true));

    _messageController.clear();
    setState(() => _replyMessage = null);
    _scrollToBottom();
  }

  void _sendImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _dbService.sendImageMessage(widget.receiverId, image, widget.receiverName, isGroup: widget.isGroup); 
    }
  }

  void _toggleReaction(String messageId, String emoji) async {
     // ... (Same Reaction Logic) ...
     String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    String chatId = widget.isGroup 
        ? widget.receiverId 
        : (currentUserId.compareTo(widget.receiverId) < 0 ? "${currentUserId}_${widget.receiverId}" : "${widget.receiverId}_$currentUserId");

    DocumentReference msgRef = FirebaseFirestore.instance.collection('chats').doc(chatId).collection('messages').doc(messageId);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(msgRef);
      if (!snapshot.exists) return;
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      Map<String, dynamic> reactions = data['reactions'] != null ? Map<String, dynamic>.from(data['reactions']) : {};
      if (reactions[currentUserId] == emoji) reactions.remove(currentUserId);
      else reactions[currentUserId] = emoji;
      transaction.update(msgRef, {'reactions': reactions});
    });
    Navigator.pop(context); 
  }

  void _showMessageOptions(Message msg, String docId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) => Container(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reaction Dock
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
                    boxShadow: [BoxShadow(color: Colors.purpleAccent.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)]
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ["❤️", "😂", "👍", "🔥", "😢", "🎉"].map((e) => 
                      GestureDetector(
                        onTap: () => _toggleReaction(docId, e),
                        child: Container(margin: const EdgeInsets.symmetric(horizontal: 5), padding: const EdgeInsets.all(5), child: Text(e, style: const TextStyle(fontSize: 32))),
                      )
                    ).toList(),
                  ),
                ),
                const SizedBox(height: 20),
                // Options List
                Container(
                  width: double.maxFinite,
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E).withOpacity(0.9), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
                  child: Column(
                    children: [
                      _buildMenuOption(Icons.reply_rounded, "Reply", () { Navigator.pop(context); setState(() => _replyMessage = msg); }),
                      const Divider(color: Colors.white10, height: 1),
                      _buildMenuOption(Icons.copy_rounded, "Copy Text", () { Navigator.pop(context); }),
                      if (msg.senderId == FirebaseAuth.instance.currentUser!.uid) ...[
                        const Divider(color: Colors.white10, height: 1),
                        _buildMenuOption(Icons.delete_outline_rounded, "Delete Message", () { Navigator.pop(context); _dbService.deleteForMe(widget.receiverId, docId); }, isDestructive: true),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuOption(IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: isDestructive ? Colors.redAccent : Colors.white, size: 22),
            const SizedBox(width: 15),
            Text(label, style: TextStyle(color: isDestructive ? Colors.redAccent : Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  void _handleMenuOption(String value) {
     if(value == 'wallpaper') _pickWallpaper();
     else _showSnack("Feature Coming Soon");
  }

  void _pickWallpaper() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _wallpaperImage = image.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fallback
      body: Stack(
        children: [
          // 🟢 1. PREMIUM BACKGROUND BLOBS (The Premium Feel)
          if (_wallpaperImage == null) ...[
             Positioned(top: -100, right: -50, child: Container(height: 300, width: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF6A11CB).withOpacity(0.3), boxShadow: [BoxShadow(color: const Color(0xFF6A11CB), blurRadius: 100, spreadRadius: 20)]))),
             Positioned(bottom: -100, left: -50, child: Container(height: 300, width: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF2575FC).withOpacity(0.3), boxShadow: [BoxShadow(color: const Color(0xFF2575FC), blurRadius: 100, spreadRadius: 20)]))),
             BackdropFilter(filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50), child: Container(color: Colors.black.withOpacity(0.4))),
          ] else 
             Positioned.fill(child: Image.file(File(_wallpaperImage!), fit: BoxFit.cover, color: Colors.black.withOpacity(0.6), colorBlendMode: BlendMode.darken)),

          // 🟢 2. MAIN CHAT CONTENT
          Column(
            children: [
              // Custom AppBar
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: widget.isGroup ? const Color(0xFF6A11CB) : Colors.purpleAccent,
                        child: widget.isGroup ? const Icon(Icons.groups, size: 20, color: Colors.white) : Text(widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(widget.receiverName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          if (!widget.isGroup)
                            StreamBuilder<bool>(
                              stream: _dbService.getTypingStatus(widget.receiverId),
                              builder: (context, snapshot) {
                                if (snapshot.data == true) return const Text("Typing...", style: TextStyle(fontSize: 12, color: Colors.blueAccent));
                                return const SizedBox(); 
                              },
                            ),
                        ]),
                      ),
                      PopupMenuButton<String>(
                        onSelected: _handleMenuOption,
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        color: const Color(0xFF1E1E1E),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'wallpaper', child: Text("Wallpaper", style: TextStyle(color: Colors.white))),
                          const PopupMenuItem(value: 'block', child: Text("Block", style: TextStyle(color: Colors.redAccent))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Messages List
              Expanded(
                child: StreamBuilder<List<Message>>(
                  stream: _dbService.getMessages(widget.receiverId, isGroup: widget.isGroup),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
                    var messages = snapshot.data!;
                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        var msg = messages[index];
                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('chats')
                              .doc(widget.isGroup ? widget.receiverId : (FirebaseAuth.instance.currentUser!.uid.compareTo(widget.receiverId) < 0 ? "${FirebaseAuth.instance.currentUser!.uid}_${widget.receiverId}" : "${widget.receiverId}_${FirebaseAuth.instance.currentUser!.uid}"))
                              .collection('messages').doc(msg.messageId).snapshots(),
                          builder: (context, msgSnap) {
                            Map<String, dynamic>? data = msgSnap.hasData ? msgSnap.data!.data() as Map<String, dynamic>? : null;
                            Map<String, dynamic> reactions = data != null && data.containsKey('reactions') ? Map<String, dynamic>.from(data['reactions']) : {};
                            Map<String, dynamic>? replyTo = data != null && data.containsKey('replyTo') ? Map<String, dynamic>.from(data['replyTo']) : null;
                            return _buildMessageItem(msg, reactions, replyTo, msgSnap.hasData ? msgSnap.data!.id : "");
                          }
                        );
                      },
                    );
                  },
                ),
              ),

              // Reply Preview
              if (_replyMessage != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: const BorderRadius.vertical(top: Radius.circular(15)), border: Border.all(color: Colors.purpleAccent.withOpacity(0.5))),
                  child: Row(
                    children: [
                      Container(width: 4, height: 40, color: Colors.purpleAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("Replying to...", style: TextStyle(color: Colors.purpleAccent, fontSize: 12)),
                          Text(_replyMessage!.text, style: const TextStyle(color: Colors.white70), maxLines: 1),
                        ]),
                      ),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => _replyMessage = null))
                    ],
                  ),
                ),

              // 🟢 3. INPUT AREA WITH VOICE RECORDER
              _isBlocked 
              ? Container(padding: const EdgeInsets.all(15), child: const Text("You blocked this user.", style: TextStyle(color: Colors.redAccent)))
              : StreamBuilder<DocumentSnapshot>(
                  stream: widget.isGroup ? FirebaseFirestore.instance.collection('chats').doc(widget.receiverId).snapshots() : null,
                  builder: (context, snapshot) {
                      // ... (Channel Restriction Check Same as before) ...
                      bool canSendMessage = true;
                      if (widget.isGroup && snapshot.hasData && snapshot.data!.exists) {
                           var data = snapshot.data!.data() as Map<String, dynamic>;
                           if ((data['isChannel'] ?? false) && data['adminId'] != FirebaseAuth.instance.currentUser!.uid) canSendMessage = false;
                      }

                      if (!canSendMessage) return Container(padding: const EdgeInsets.all(20), child: const Text("ONLY ADMIN CAN POST", style: TextStyle(color: Colors.white54)));

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08), // Glassy Input
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            if (_isRecording) ...[
                              // 🎙️ RECORDING UI
                              const Icon(Icons.mic, color: Colors.redAccent, size: 24),
                              const SizedBox(width: 10),
                              const Text("Recording...", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              TextButton(onPressed: _cancelRecording, child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
                              CircleAvatar(
                                backgroundColor: Colors.redAccent,
                                child: IconButton(icon: const Icon(Icons.stop, color: Colors.white), onPressed: _stopAndSendRecording),
                              )
                            ] else ...[
                              // 📝 TYPING UI
                              IconButton(icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey), onPressed: () {}),
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    hintText: "Message...",
                                    hintStyle: TextStyle(color: Colors.grey),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              IconButton(icon: const Icon(Icons.camera_alt, color: Colors.grey), onPressed: _sendImage),
                              const SizedBox(width: 5),
                              
                              // Send Button handles both Text and Mic
                              _isTyping 
                                ? CircleAvatar(backgroundColor: const Color(0xFF6A11CB), child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendMessage))
                                : GestureDetector(
                                    onTap: _startRecording, // Tap to start recording
                                    child: const CircleAvatar(backgroundColor: Color(0xFF2575FC), child: Icon(Icons.mic, color: Colors.white, size: 20)),
                                  )
                            ]
                          ],
                        ),
                      );
                  }
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(Message msg, Map<String, dynamic> reactions, Map<String, dynamic>? replyTo, String docId) {
    bool isMe = msg.senderId == FirebaseAuth.instance.currentUser!.uid;
    DateTime dt = msg.timestamp.toDate();
    String timeString = "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    Map<String, int> reactionCounts = {};
    reactions.forEach((key, value) => reactionCounts[value] = (reactionCounts[value] ?? 0) + 1);

    return GestureDetector(
      onLongPress: () => _showMessageOptions(msg, docId),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: isMe ? const LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)]) : null,
                  color: isMe ? null : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4), bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18)),
                  border: isMe ? null : Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (replyTo != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: const Border(left: BorderSide(color: Colors.white, width: 3))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(replyTo['sender'] ?? "Unknown", style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          Text(replyTo['text'] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1),
                        ]),
                      ),
                    
                    if (widget.isGroup && !isMe)
                      Text(msg.senderName ?? "Member", style: TextStyle(color: Colors.purpleAccent[100], fontSize: 11, fontWeight: FontWeight.bold)),

                    // 🎙️ MESSAGE CONTENT TYPE SWITCH
                    if (msg.type == 'image') 
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: CachedNetworkImage(imageUrl: msg.text, height: 200, width: 200, fit: BoxFit.cover))
                    else if (msg.type == 'audio')
                      // 🎧 AUDIO BUBBLE
                      Container(
                        width: 150,
                        padding: const EdgeInsets.all(5),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _playAudio(msg.text),
                              child: Icon(
                                (_currentlyPlayingUrl == msg.text && _isPlaying) ? Icons.pause_circle_filled : Icons.play_circle_fill, 
                                color: Colors.white, size: 30
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Container(height: 3, color: Colors.white54)), // Fake Waveform
                          ],
                        ),
                      )
                    else 
                      Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 16)),

                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text(timeString, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
                      if(isMe) Icon(Icons.done_all, size: 14, color: msg.isRead ? Colors.white : Colors.white54)
                    ]),
                  ],
                ),
              ),
              if (reactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
                    child: Text(reactionCounts.keys.join(" "), style: const TextStyle(fontSize: 12)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}