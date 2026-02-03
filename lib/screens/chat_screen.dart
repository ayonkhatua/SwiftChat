import 'dart:io';
import 'dart:ui';
import 'dart:async'; // Timer ke liye
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/database_service.dart';
import '../models/message_model.dart';
import 'wallet_screen.dart'; // 🟢 Premium Check ke liye

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
  // 🟢 VARIABLES
  final TextEditingController _messageController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  final ScrollController _scrollController = ScrollController();
  
  // Audio State
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _currentlyPlayingUrl;
  bool _isPlaying = false;
  
  // UI State
  bool _isTyping = false;
  String? _wallpaperImage;
  bool _isBlocked = false;
  
  // Reply, Edit & Highlight State
  Message? _replyMessage;
  Message? _editingMessage;
  String? _highlightedMessageId; // 🔦 Highlight Effect

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
      if(mounted) {
        setState(() {
          _currentlyPlayingUrl = null;
          _isPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 🟢 LOGIC FUNCTIONS

  void _checkBlockStatus() {
    _dbService.isUserBlocked(widget.receiverId).listen((isBlocked) {
      if(mounted) setState(() => _isBlocked = isBlocked);
    });
  }

  // 🔦 HIGHLIGHT LOGIC
  void _scrollToAndHighlight(String messageId) {
    setState(() {
      _highlightedMessageId = messageId;
    });
    // 1 second baad highlight hata do
    Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _highlightedMessageId = null);
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent, 
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeOut
      );
    }
  }

  // 📌 PIN OPTIONS & LOGIC
  void _showPinOptions(Message msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white12)
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Pin Message For...", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              _pinOptionTile("7 Days", 7, msg),
              _pinOptionTile("15 Days", 15, msg),
              _pinOptionTile("30 Days", 30, msg),
              _pinOptionTile("Unlimited (Lifetime)", -1, msg, isPremium: true), // 👑 Premium
              
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _pinOptionTile(String title, int days, Message msg, {bool isPremium = false}) {
    return ListTile(
      leading: Icon(Icons.push_pin, color: isPremium ? const Color(0xFFFFD700) : Colors.blueAccent),
      title: Row(
        children: [
          Text(title, style: TextStyle(color: isPremium ? const Color(0xFFFFD700) : Colors.white)),
          if(isPremium) ...[const SizedBox(width: 10), const Icon(Icons.star, color: Color(0xFFFFD700), size: 16)]
        ],
      ),
      onTap: () async {
        Navigator.pop(context); // Close sheet
        if (isPremium) {
          // 💎 Check Premium Status
          bool userIsPremium = await _dbService.isUserPremium();
          if (!userIsPremium) {
            _showPremiumLockDialog();
            return;
          }
        }
        _pinMessage(msg, days);
      },
    );
  }

  void _pinMessage(Message msg, int days) async {
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    String chatId = widget.isGroup 
        ? widget.receiverId 
        : (currentUserId.compareTo(widget.receiverId) < 0 ? "${currentUserId}_${widget.receiverId}" : "${widget.receiverId}_$currentUserId");

    // Calculate Expiry
    Timestamp? expiry;
    if (days != -1) {
      DateTime exDate = DateTime.now().add(Duration(days: days));
      expiry = Timestamp.fromDate(exDate);
    }

    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
      'pinnedMessages': FieldValue.arrayUnion([{
        'text': msg.type == 'image' ? "📷 Photo" : msg.text,
        'id': msg.messageId,
        'sender': msg.senderName,
        'expiry': expiry,
        'isLifetime': days == -1
      }])
    });
    _showSnack(days == -1 ? "Pinned Forever! 👑" : "Pinned for $days days 📌");
  }

  void _unpinMessage(Map<String, dynamic> pinData) async {
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    String chatId = widget.isGroup ? widget.receiverId : (currentUserId.compareTo(widget.receiverId) < 0 ? "${currentUserId}_${widget.receiverId}" : "${widget.receiverId}_$currentUserId");
    await FirebaseFirestore.instance.collection('chats').doc(chatId).update({'pinnedMessages': FieldValue.arrayRemove([pinData])});
    _showSnack("Message Unpinned");
  }

  void _showPremiumLockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Premium Feature 👑", style: TextStyle(color: Color(0xFFFFD700))),
        content: const Text("Unlimited Pinning is only for Premium users.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A11CB)),
            onPressed: () {
               Navigator.pop(context);
               Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())); 
            },
            child: const Text("Upgrade Now"),
          )
        ],
      )
    );
  }

  // 🎙️ RECORDING & AUDIO
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

  // 📨 SEND MESSAGE
  void _sendMessage() async {
    String text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    // Edit Logic
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

    if (!widget.isGroup) {
      bool amIBlocked = await _dbService.amIBlockedBy(widget.receiverId);
      if (amIBlocked) { _showSnack("You cannot send messages."); return; }
      if (_isBlocked) { _showSnack("Unblock user first."); return; }
    }

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

  void _toggleReaction(String docId, String emoji) async {
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    String chatId = widget.isGroup 
        ? widget.receiverId 
        : (currentUserId.compareTo(widget.receiverId) < 0 ? "${currentUserId}_${widget.receiverId}" : "${widget.receiverId}_$currentUserId");

    await _dbService.toggleReaction(chatId, docId, emoji);
    Navigator.pop(context); 
  }

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
                stream: _dbService.getMyFriends(), 
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

  // 📱 MENU & REACTIONS
  void _showMessageOptions(Message msg, String docId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.6),
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
                color: const Color(0xFF1E1E1E).withOpacity(0.95),
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
                        children: [
                          ...["❤️", "👍", "👎", "🔥", "😂", "😢", "😡"].map((e) => 
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
                          // 🔽 DOWN ARROW
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              _showCustomReactionInput(docId);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
                              child: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  
                  // 2. OPTIONS LIST
                  Column(
                    children: [
                      _buildMenuItem(Icons.reply, "Reply", () { Navigator.pop(context); setState(() => _replyMessage = msg); }),
                      _buildMenuItem(Icons.copy, "Copy", () { Clipboard.setData(ClipboardData(text: msg.text)); Navigator.pop(context); _showSnack("Copied!"); }),
                      _buildMenuItem(Icons.forward, "Forward", () => _forwardMessage(msg)),
                      // 🟢 OPEN NEW PIN DIALOG
                      _buildMenuItem(Icons.push_pin, "Pin", () { Navigator.pop(context); _showPinOptions(msg); }), 
                      
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

  void _showCustomReactionInput(String docId) {
    TextEditingController customEmojiController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Type an Emoji", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: customEmojiController,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 30, color: Colors.white),
          decoration: const InputDecoration(border: InputBorder.none, hintText: "😀", hintStyle: TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(
            onPressed: () { 
              if(customEmojiController.text.isNotEmpty) {
                _toggleReaction(docId, customEmojiController.text.characters.first); 
              } else {
                Navigator.pop(context);
              }
            }, 
            child: const Text("React", style: TextStyle(color: Colors.blueAccent))
          )
        ],
      )
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

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xFF6A11CB)));
  }

  void _pickWallpaper() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _wallpaperImage = image.path);
  }

  // ---------------------------------------------------
  // 🟢 4. BUILD UI (Scaffold)
  // ---------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      body: Stack(
        children: [
          // BACKGROUND
          if (_wallpaperImage == null) ...[
             Positioned(top: -100, right: -50, child: Container(height: 300, width: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF6A11CB).withOpacity(0.3), boxShadow: [BoxShadow(color: const Color(0xFF6A11CB), blurRadius: 100, spreadRadius: 20)]))),
             Positioned(bottom: -100, left: -50, child: Container(height: 300, width: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF2575FC).withOpacity(0.3), boxShadow: [BoxShadow(color: const Color(0xFF2575FC), blurRadius: 100, spreadRadius: 20)]))),
             BackdropFilter(filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50), child: Container(color: Colors.black.withOpacity(0.4))),
          ] else 
             Positioned.fill(child: Image.file(File(_wallpaperImage!), fit: BoxFit.cover, color: Colors.black.withOpacity(0.6), colorBlendMode: BlendMode.darken)),

          Column(
            children: [
              // 🟢 APP BAR WITH MULTIPLE PINNED MESSAGES (CAROUSEL)
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
                    
                    // 📌 MULTIPLE PINNED MESSAGE CAROUSEL
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('chats').doc(widget.isGroup ? widget.receiverId : (FirebaseAuth.instance.currentUser!.uid.compareTo(widget.receiverId) < 0 ? "${FirebaseAuth.instance.currentUser!.uid}_${widget.receiverId}" : "${widget.receiverId}_${FirebaseAuth.instance.currentUser!.uid}")).snapshots(),
                      builder: (context, snapshot) {
                        if(!snapshot.hasData) return const SizedBox();
                        var data = snapshot.data!.data() as Map<String, dynamic>?;
                        List pins = [];
                        if (data != null) {
                          if (data.containsKey('pinnedMessages')) {
                            pins = List.from(data['pinnedMessages']);
                          } else if (data.containsKey('pinnedMessage')) {
                            pins = [data['pinnedMessage']];
                          }
                        }
                        if(pins.isEmpty) return const SizedBox();

                        return Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(color: Colors.grey[900], border: const Border(left: BorderSide(color: Colors.blueAccent, width: 4))),
                          child: PageView.builder(
                            itemCount: pins.length,
                            scrollDirection: Axis.vertical,
                            itemBuilder: (context, index) {
                              var pin = pins[index];
                              return GestureDetector(
                                onTap: () => _scrollToAndHighlight(pin['id']), // 🔦 Highlight
                                onLongPress: () => _unpinMessage(pin),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.push_pin, color: Colors.blueAccent, size: 16),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(pin['sender'] ?? "Pinned", style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                            Text(pin['text'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.close, size: 14, color: Colors.grey)
                                    ],
                                  ),
                                ),
                              );
                            },
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
                GestureDetector(
                  onTap: () {
                     if(_replyMessage != null) _scrollToAndHighlight(_replyMessage!.messageId);
                  },
                  child: Container(
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

    // 🔦 HIGHLIGHT LOGIC CHECK
    bool isHighlighted = _highlightedMessageId == msg.messageId;

    // 🟢 SWIPE TO REPLY (Dismissible)
    return Dismissible(
      key: Key(msg.messageId),
      direction: DismissDirection.startToEnd, // Right Swipe
      confirmDismiss: (dir) async {
        setState(() => _replyMessage = msg);
        return false; // Don't Delete
      },
      background: Container(
        color: Colors.transparent,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.reply, color: Colors.blueAccent),
      ),
      child: GestureDetector(
        onTap: () => _showMessageOptions(msg, msg.messageId), 
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          color: isHighlighted ? Colors.white.withOpacity(0.2) : Colors.transparent, // ✨ Flash Effect
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
                      // Reply Preview in bubble
                      if (msg.replyTo != null)
                        GestureDetector(
                          onTap: () => _scrollToAndHighlight(msg.replyTo!['id'] ?? ""),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: const Border(left: BorderSide(color: Colors.white, width: 3))),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(msg.replyTo!['sender'] ?? "Unknown", style: const TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                              Text(msg.replyTo!['text'] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 1),
                            ]),
                          ),
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
                      
                      // 🟢 INSTAGRAM STYLE STATUS (Sent -> Seen)
                      Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
                        Text(timeString, style: TextStyle(color: Colors.white70, fontSize: 10)),
                        if(isMe) ...[
                          const SizedBox(width: 5),
                          Text(
                            msg.isRead ? "Seen" : "Sent", 
                            style: TextStyle(
                              color: msg.isRead ? Colors.white70 : Colors.white30, 
                              fontSize: 10, 
                              fontWeight: FontWeight.bold
                            )
                          )
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
      ),
    );
  }
}
