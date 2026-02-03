import 'dart:io';
import 'dart:ui'; // Glass effect
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart'; // 🟢 FIXED: YE MISSING THA
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
  
  // 🔄 Reply & Edit State
  Message? _replyMessage;
  Message? _editingMessage; // ✏️ Editing ke liye

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

  // 🎙️ RECORDING LOGIC
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

  Future<void> _stopAndSendRecording() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    if (path != null) {
      await _dbService.sendAudioMessage(widget.receiverId, path, widget.receiverName, isGroup: widget.isGroup);
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

  // 📨 SEND / EDIT MESSAGE LOGIC
  void _sendMessage() async {
    String text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    // ✏️ EDIT MODE
    if (_editingMessage != null) {
      String currentUserId = FirebaseAuth.instance.currentUser!.uid;
      String chatId = widget.isGroup ? widget.receiverId : 
        (currentUserId.compareTo(widget.receiverId) < 0 ? "${currentUserId}_${widget.receiverId}" : "${widget.receiverId}_$currentUserId");
      
      await FirebaseFirestore.instance.collection('chats').doc(chatId)
          .collection('messages').doc(_editingMessage!.messageId).update({'text': text});
      
      setState(() => _editingMessage = null);
      _messageController.clear();
      return;
    }

    // NORMAL SEND
    if (!widget.isGroup) {
      bool amIBlocked = await _dbService.amIBlockedBy(widget.receiverId);
      if (amIBlocked) { _showSnack("You cannot send messages."); return; }
      if (_isBlocked) { _showSnack("Unblock user first."); return; }
    }

    // 🟢 USING DATABASE SERVICE (Updated for Reply)
    await _dbService.sendMessage(
      widget.receiverId, 
      text, 
      widget.receiverName, 
      isGroup: widget.isGroup,
      replyTo: _replyMessage != null ? {
        'text': _replyMessage!.type == 'image' ? "📷 Photo" : (_replyMessage!.type == 'audio' ? "🎤 Voice Note" : _replyMessage!.text),
        'sender': _replyMessage!.senderName,
        'id': _replyMessage!.messageId
      } : null
    );

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

  // ❤️ REACTION LOGIC
  void _toggleReaction(String docId, String emoji) async {
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    String chatId = widget.isGroup 
        ? widget.receiverId 
        : (currentUserId.compareTo(widget.receiverId) < 0 ? "${currentUserId}_${widget.receiverId}" : "${widget.receiverId}_$currentUserId");

    await _dbService.toggleReaction(chatId, docId, emoji);
    Navigator.pop(context); 
  }

  // 📌 PIN LOGIC
  void _pinMessage(Message msg) async {
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    String chatId = widget.isGroup 
        ? widget.receiverId 
        : (currentUserId.compareTo(widget.receiverId) < 0 ? "${currentUserId}_${widget.receiverId}" : "${widget.receiverId}_$currentUserId");

    // Toggle Pin (Simple Implementation: Update chat metadata)
    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'pinnedMessage': {
        'text': msg.type == 'image' ? "📷 Photo" : msg.text,
        'id': msg.messageId,
        'sender': msg.senderName
      }
    });
    Navigator.pop(context);
    _showSnack("Message Pinned 📌");
  }

  // ⏩ FORWARD LOGIC
  void _forwardMessage(Message msg) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return Column(
          children: [
            const Padding(padding: EdgeInsets.all(15), child: Text("Forward to...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _dbService.getMyFriends(), // Forward to friends
                builder: (context, snapshot) {
                  if(!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  var friends = snapshot.data!;
                  return ListView.builder(
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      var friend = friends[index];
                      return ListTile(
                        leading: CircleAvatar(backgroundImage: CachedNetworkImageProvider(friend['profile_pic'] ?? "")),
                        title: Text(friend['username'], style: const TextStyle(color: Colors.white)),
                        trailing: IconButton(
                          icon: const Icon(Icons.send, color: Colors.blueAccent),
                          onPressed: () {
                             // Send as new message
                             _dbService.sendMessage(friend['uid'], msg.text, friend['username']);
                             Navigator.pop(context);
                             _showSnack("Forwarded to ${friend['username']}");
                          },
                        ),
                      );
                    },
                  );
                }
              ),
            )
          ],
        );
      }
    );
  }

  // 📱 TELEGRAM STYLE SINGLE TAP MENU
  void _showMessageOptions(Message msg, String docId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.6), // Dim Background
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) => Container(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            content: Container(
              width: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E).withOpacity(0.95), // Dark Telegram Grey
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20, spreadRadius: 5)]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. REACTIONS ROW
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ["❤️", "👍", "👎", "🔥", "🥰", "👏", "😂", "😮", "😢"].map((e) => 
                          GestureDetector(
                            onTap: () => _toggleReaction(docId, e),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
                              child: Text(e, style: const TextStyle(fontSize: 26)),
                            ),
                          )
                        ).toList(),
                      ),
                    ),
                  ),
                  
                  // 2. OPTIONS LIST
                  Column(
                    children: [
                      _buildMenuItem(Icons.reply, "Reply", () { Navigator.pop(context); setState(() => _replyMessage = msg); }),
                      _buildMenuItem(Icons.copy, "Copy", () { Clipboard.setData(ClipboardData(text: msg.text)); Navigator.pop(context); _showSnack("Copied!"); }),
                      _buildMenuItem(Icons.forward, "Forward", () => _forwardMessage(msg)),
                      _buildMenuItem(Icons.push_pin, "Pin", () => _pinMessage(msg)),
                      
                      if (msg.senderId == FirebaseAuth.instance.currentUser!.uid) ...[
                        _buildMenuItem(Icons.edit, "Edit", () { 
                          Navigator.pop(context); 
                          setState(() { 
                            _editingMessage = msg; 
                            _messageController.text = msg.text; 
                          }); 
                        }),
                        _buildMenuItem(Icons.delete, "Delete", () { 
                          Navigator.pop(context); 
                          _dbService.deleteForMe(widget.receiverId, docId); 
                        }, isDestructive: true),
                      ]
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: isDestructive ? Colors.redAccent : Colors.white70, size: 22),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFF6A11CB)));
  }

  void _pickWallpaper() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _wallpaperImage = image.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      body: Stack(
        children: [
          // BACKGROUND BLOBS & WALLPAPER
          if (_wallpaperImage == null) ...[
             Positioned(top: -100, right: -50, child: Container(height: 300, width: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF6A11CB).withOpacity(0.3), boxShadow: [BoxShadow(color: const Color(0xFF6A11CB), blurRadius: 100, spreadRadius: 20)]))),
             Positioned(bottom: -100, left: -50, child: Container(height: 300, width: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF2575FC).withOpacity(0.3), boxShadow: [BoxShadow(color: const Color(0xFF2575FC), blurRadius: 100, spreadRadius: 20)]))),
             BackdropFilter(filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50), child: Container(color: Colors.black.withOpacity(0.4))),
          ] else 
             Positioned.fill(child: Image.file(File(_wallpaperImage!), fit: BoxFit.cover, color: Colors.black.withOpacity(0.6), colorBlendMode: BlendMode.darken)),

          Column(
            children: [
              // 🟢 APP BAR WITH PINNED MESSAGE
              SafeArea(
                child: Column(
                  children: [
                    Container(
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
                                    // 🟢 Presence Status (Instagram Style)
                                    return StreamBuilder<DatabaseEvent>(
                                      stream: _dbService.getUserStatus(widget.receiverId),
                                      builder: (context, statSnap) {
                                        if(!statSnap.hasData || statSnap.data!.snapshot.value == null) return const Text("Offline", style: TextStyle(fontSize: 12, color: Colors.grey));
                                        var val = statSnap.data!.snapshot.value as Map;
                                        return Text(val['state'] == 'online' ? "Active now" : "Offline", style: TextStyle(fontSize: 12, color: val['state'] == 'online' ? Colors.greenAccent : Colors.grey));
                                      }
                                    );
                                  },
                                ),
                            ]),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white),
                            color: const Color(0xFF1E1E1E),
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'wallpaper', child: Text("Wallpaper", style: TextStyle(color: Colors.white))),
                              const PopupMenuItem(value: 'block', child: Text("Block", style: TextStyle(color: Colors.redAccent))),
                            ],
                            onSelected: (val) => val == 'wallpaper' ? _pickWallpaper() : null,
                          ),
                        ],
                      ),
                    ),
                    // 📌 PINNED MESSAGE BAR
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('chats').doc(widget.isGroup ? widget.receiverId : (FirebaseAuth.instance.currentUser!.uid.compareTo(widget.receiverId) < 0 ? "${FirebaseAuth.instance.currentUser!.uid}_${widget.receiverId}" : "${widget.receiverId}_${FirebaseAuth.instance.currentUser!.uid}")).snapshots(),
                      builder: (context, snapshot) {
                        if(!snapshot.hasData) return const SizedBox();
                        var data = snapshot.data!.data() as Map<String, dynamic>?;
                        if(data == null || !data.containsKey('pinnedMessage')) return const SizedBox();
                        var pin = data['pinnedMessage'];
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                          decoration: BoxDecoration(color: Colors.grey[900], border: const Border(left: BorderSide(color: Colors.blueAccent, width: 4))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Pinned Message", style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                              Text(pin['text'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        );
                      },
                    )
                  ],
                ),
              ),

              // MESSAGES LIST
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
                        return _buildMessageItem(messages[index]);
                      },
                    );
                  },
                ),
              ),

              // REPLY / EDIT PREVIEW
              if (_replyMessage != null || _editingMessage != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: const BorderRadius.vertical(top: Radius.circular(15)), border: Border.all(color: Colors.purpleAccent.withOpacity(0.5))),
                  child: Row(
                    children: [
                      Icon(_editingMessage != null ? Icons.edit : Icons.reply, color: Colors.purpleAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_editingMessage != null ? "Editing Message" : "Replying to ${_replyMessage!.senderName}", style: const TextStyle(color: Colors.purpleAccent, fontSize: 12)),
                          Text(_editingMessage != null ? _editingMessage!.text : _replyMessage!.text, style: const TextStyle(color: Colors.white70), maxLines: 1),
                        ]),
                      ),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() { _replyMessage = null; _editingMessage = null; _messageController.clear(); }))
                    ],
                  ),
                ),

              // INPUT AREA
              _isBlocked 
              ? Container(padding: const EdgeInsets.all(15), child: const Text("You blocked this user.", style: TextStyle(color: Colors.redAccent)))
              : Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.black87, border: Border(top: BorderSide(color: Colors.white12))),
                  child: Row(
                    children: [
                      if (_isRecording) ...[
                        const Icon(Icons.mic, color: Colors.redAccent),
                        const SizedBox(width: 10),
                        const Text("Recording...", style: TextStyle(color: Colors.redAccent)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.stop, color: Colors.redAccent), onPressed: _stopAndSendRecording)
                      ] else ...[
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: "Message...",
                              hintStyle: const TextStyle(color: Colors.grey),
                              filled: true,
                              fillColor: Colors.white10,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                              suffixIcon: IconButton(icon: const Icon(Icons.camera_alt, color: Colors.grey), onPressed: _sendImage),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        GestureDetector(
                          onTap: _isTyping ? _sendMessage : _startRecording,
                          child: CircleAvatar(
                            backgroundColor: _isTyping ? const Color(0xFF6A11CB) : Colors.blueAccent,
                            child: Icon(_isTyping ? Icons.send : Icons.mic, color: Colors.white, size: 20),
                          ),
                        )
                      ]
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(Message msg) {
    bool isMe = msg.senderId == FirebaseAuth.instance.currentUser!.uid;
    DateTime dt = msg.timestamp.toDate();
    String timeString = "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    Map<String, int> reactionCounts = {};
    msg.reactions.forEach((key, value) => reactionCounts[value] = (reactionCounts[value] ?? 0) + 1);

    return GestureDetector(
      onTap: () => _showMessageOptions(msg, msg.messageId), // 🟢 SINGLE TAP MENU
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
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (msg.replyTo != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: const Border(left: BorderSide(color: Colors.white, width: 3))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(msg.replyTo!['sender'] ?? "Unknown", style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          Text(msg.replyTo!['text'] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1),
                        ]),
                      ),
                    
                    if (widget.isGroup && !isMe)
                      Text(msg.senderName ?? "Member", style: TextStyle(color: Colors.purpleAccent[100], fontSize: 11, fontWeight: FontWeight.bold)),

                    if (msg.type == 'image') 
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: CachedNetworkImage(imageUrl: msg.text, height: 200, width: 200, fit: BoxFit.cover))
                    else if (msg.type == 'audio')
                      Container(
                        width: 150,
                        padding: const EdgeInsets.all(5),
                        child: Row(children: [GestureDetector(onTap: () => _playAudio(msg.text), child: Icon((_currentlyPlayingUrl == msg.text && _isPlaying) ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white, size: 30)), const SizedBox(width: 10), Expanded(child: Container(height: 3, color: Colors.white54))]),
                      )
                    else 
                      Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 16)),

                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text(timeString, style: TextStyle(color: Colors.white70, fontSize: 10)),
                      if(isMe) ...[
                        const SizedBox(width: 5),
                        // 🟢 Instagram Style Status (Check, Double Check, Blue Check)
                        Icon(Icons.done_all, size: 14, color: msg.isRead ? Colors.blueAccent : Colors.white54) 
                      ]
                    ]),
                  ],
                ),
              ),
              if (msg.reactions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, right: 5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
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