import 'dart:io';
import 'dart:ui';
import 'dart:async';
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
import 'wallet_screen.dart';
import '../services/cloudinary_service.dart';
import 'home_screen.dart'; 

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

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
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
  String? _highlightedMessageId; 

  // 🔍 Pin Scroll Logic Helper
  List<Message> _currentMessagesList = []; 

  int _currentPinIndex = 0; // 🟢 Added for Telegram-style Pin Looping

  // 🌊 Animation Controller for Voice Wave
  late AnimationController _waveController;

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

    // 🌊 Initialize Wave Animation
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
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

  void _scrollToAndHighlight(String messageId) {
    setState(() {
      _highlightedMessageId = messageId;
    });

    int index = _currentMessagesList.indexWhere((m) => m.messageId == messageId);
    if (index != -1) {
      double offset = index * 80.0; 
      if (offset > _scrollController.position.maxScrollExtent) {
         offset = _scrollController.position.maxScrollExtent;
      }
      
      _scrollController.animateTo(
        offset, 
        duration: const Duration(milliseconds: 600), 
        curve: Curves.easeInOut
      );
    }

    Timer(const Duration(seconds: 2), () {
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

  // 📌 SMART PIN OPTIONS
  void _showPinOptions(Message msg) async {
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    String chatId = widget.isGroup 
        ? widget.receiverId 
        : (currentUserId.compareTo(widget.receiverId) < 0 ? "${currentUserId}_${widget.receiverId}" : "${widget.receiverId}_$currentUserId");
    
    DocumentSnapshot chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
    
    bool isAlreadyPinned = false;
    Map<String, dynamic>? pinnedData;
    
    if(chatDoc.exists) {
      List pins = chatDoc.get('pinnedMessages') ?? [];
      var existing = pins.where((p) => p['id'] == msg.messageId);
      if(existing.isNotEmpty) {
        isAlreadyPinned = true;
        pinnedData = existing.first;
      }
    }

    if (!mounted) return;

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
              Text(isAlreadyPinned ? "Manage Pin" : "Pin Message For...", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              if (isAlreadyPinned)
                ListTile(
                  leading: const Icon(Icons.push_pin_outlined, color: Colors.redAccent),
                  title: const Text("Unpin Message", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _unpinMessage(pinnedData!);
                  },
                )
              else ...[
                _pinOptionTile("7 Days", 7, msg),
                _pinOptionTile("15 Days", 15, msg),
                _pinOptionTile("30 Days", 30, msg),
                _pinOptionTile("Unlimited (Lifetime)", -1, msg, isPremium: true), // 👑 Premium
              ],
              
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
        Navigator.pop(context); 
        if (isPremium) {
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
        title: const Text("VIP Feature 👑", style: TextStyle(color: Color(0xFFFFD700))),
        content: const Text("Unlimited Pinning is for VIP users only.", style: TextStyle(color: Colors.white70)),
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

  // 🎁 GIFT COINS LOGIC
  void _sendGift() {
    TextEditingController amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Gift Coins 🎁", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("1 Coin = ₹1", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter Amount",
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.monetization_on, color: Colors.amber),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.redAccent))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A11CB)),
            onPressed: () async {
              int? amount = int.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                _showSnack("Invalid amount");
                return;
              }
              Navigator.pop(context);
              await _processGiftTransaction(amount);
            },
            child: const Text("Send Gift"),
          )
        ],
      )
    );
  }

  Future<void> _processGiftTransaction(int amount) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (user.uid == widget.receiverId) {
      _showSnack("You cannot gift yourself!");
      return;
    }

    DocumentReference senderWallet = FirebaseFirestore.instance.collection('wallets').doc(user.uid);
    DocumentReference receiverWallet = FirebaseFirestore.instance.collection('wallets').doc(widget.receiverId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot senderSnap = await transaction.get(senderWallet);
        if (!senderSnap.exists) throw Exception("Insufficient Balance");
        
        Map<String, dynamic> data = senderSnap.data() as Map<String, dynamic>;
        int purchased = data['purchasedCoins'] ?? 0;
        int gifted = data['giftedCoins'] ?? 0;
        int total = purchased + gifted;

        if (total < amount) throw Exception("Insufficient Balance");

        int newPurchased = purchased;
        int newGifted = gifted;

        if (purchased >= amount) {
          newPurchased -= amount;
        } else {
          int remaining = amount - purchased;
          newPurchased = 0;
          newGifted -= remaining;
        }

        transaction.update(senderWallet, {'purchasedCoins': newPurchased, 'giftedCoins': newGifted});
        transaction.set(receiverWallet, {'giftedCoins': FieldValue.increment(amount)}, SetOptions(merge: true));
      });

      await _dbService.sendMessage(widget.receiverId, "🎁 Gifted $amount Coins", widget.receiverName, isGroup: widget.isGroup);
      _showSnack("Sent $amount Coins! 🎁");

    } catch (e) {
      if (e.toString().contains("Insufficient Balance")) {
        _showSnack("Insufficient Balance! Buy more coins.");
        Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
      } else {
        _showSnack("Transaction Failed: $e");
      }
    }
  }

  // ☁️ CLOUDINARY & FIRESTORE DIRECT SEND
  Future<void> _sendMediaMessage(String url, String type) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String chatId = widget.isGroup 
        ? widget.receiverId 
        : (user.uid.compareTo(widget.receiverId) < 0 ? "${user.uid}_${widget.receiverId}" : "${widget.receiverId}_${user.uid}");

    DocumentReference chatDoc = FirebaseFirestore.instance.collection('chats').doc(chatId);
    
    Map<String, dynamic> messageData = {
      'senderId': user.uid,
      'senderName': widget.isGroup ? (user.displayName ?? "Member") : user.displayName,
      'text': url, // Cloudinary URL
      'type': type, // 'image' or 'audio'
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'reactions': {},
    };

    // Add to subcollection
    await chatDoc.collection('messages').add(messageData);

    // Update Last Message
    String lastMsgText = type == 'image' ? "📷 Photo" : "🎤 Voice Note";
    await chatDoc.set({
      'lastMessage': lastMsgText,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'recentUpdated': FieldValue.serverTimestamp(),
      if (!widget.isGroup) 'users': {user.uid: user.displayName, widget.receiverId: widget.receiverName},
      if (!widget.isGroup) 'participants': [user.uid, widget.receiverId],
    }, SetOptions(merge: true));

    // Send Notification (Optional: relying on existing notification service triggers or manual)
    // _dbService.sendNotification(...) - Assuming DB service handles this via cloud functions or we skip for now
  }

  // ️ RECORDING & AUDIO
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
      _showSnack("Uploading Audio...");
      // Upload to Cloudinary (Audio treated as video resource often works best)
      String? url = await CloudinaryService().uploadFile(File(path), isVideo: true);
      
      if (url != null) {
        await _sendMediaMessage(url, 'audio');
      } else {
        _showSnack("Audio Upload Failed");
      }
    }
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
      _showSnack("Uploading Image...");
      String? url = await CloudinaryService().uploadFile(File(image.path));
      
      if (url != null) {
        await _sendMediaMessage(url, 'image');
      } else {
        _showSnack("Image Upload Failed");
      }
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
        return Stack(
          alignment: Alignment.center,
          children: [
            ScaleTransition(
              scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. REACTIONS ROW
                  Material(
                    color: Colors.transparent,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)]
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...["❤️", "👍", "👎", "🔥", "😂", "😢", "😡"].map((e) => 
                              GestureDetector(
                                onTap: () {
                                  _toggleReaction(docId, e);
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 5),
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.transparent),
                                  child: Text(e, style: const TextStyle(fontSize: 28)),
                                ),
                              )
                            ).toList(),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                _showCustomReactionInput(docId);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
                                child: const Icon(Icons.add, color: Colors.white70, size: 24),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // 2. OPTIONS LIST
                  Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 250,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E).withOpacity(0.95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          _buildMenuItem(Icons.reply, "Reply", () { Navigator.pop(context); setState(() => _replyMessage = msg); }),
                          _buildMenuItem(Icons.copy, "Copy", () { Clipboard.setData(ClipboardData(text: msg.text)); Navigator.pop(context); _showSnack("Copied!"); }),
                          _buildMenuItem(Icons.forward, "Forward", () => _forwardMessage(msg)),
                          _buildMenuItem(Icons.push_pin, "Pin Message", () { Navigator.pop(context); _showPinOptions(msg); }), 
                          
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
                    ),
                  ),
                ],
              ),
            ),
          ],
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
             Positioned(top: -100, right: -50, child: Container(height: 300, width: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF6A11CB).withOpacity(0.3), boxShadow: const [BoxShadow(color: Color(0xFF6A11CB), blurRadius: 100, spreadRadius: 20)]))),
             Positioned(bottom: -100, left: -50, child: Container(height: 300, width: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF2575FC).withOpacity(0.3), boxShadow: const [BoxShadow(color: Color(0xFF2575FC), blurRadius: 100, spreadRadius: 20)]))),
             BackdropFilter(filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50), child: Container(color: Colors.black.withOpacity(0.4))),
          ] else 
             Positioned.fill(child: Image.file(File(_wallpaperImage!), fit: BoxFit.cover, color: Colors.black.withOpacity(0.6), colorBlendMode: BlendMode.darken)),

          Column(
            children: [
              // 🟢 APP BAR WITH VIP HEADER
              SafeArea(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: Row(
                        children: [
                          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                          
                          // 🟢 HEADER LOGIC: Get User Level & Show VIP Name
                          Expanded(
                            child: StreamBuilder<DocumentSnapshot>(
                              stream: widget.isGroup 
                                ? null 
                                : FirebaseFirestore.instance.collection('users').doc(widget.receiverId).snapshots(),
                              builder: (context, snapshot) {
                                String name = widget.receiverName;
                                int membershipLevel = 0;
                                String? image;

                                if (snapshot.hasData && snapshot.data!.exists) {
                                  var d = snapshot.data!.data() as Map<String, dynamic>;
                                  name = d['username'] ?? name;
                                  membershipLevel = d['membershipLevel'] ?? 0;
                                  image = d['profile_pic'];
                                }
                                
                                if(widget.isGroup) image = null; // Use group icon logic if stored in chat doc

                                return Row(
                                  children: [
                                    // Avatar
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: widget.isGroup ? const Color(0xFF6A11CB) : Colors.purpleAccent,
                                      backgroundImage: image != null ? CachedNetworkImageProvider(image) : null,
                                      child: (image == null) 
                                        ? (widget.isGroup ? const Icon(Icons.groups, size: 20, color: Colors.white) : Text(name.isNotEmpty ? name[0].toUpperCase() : "?", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
                                        : null,
                                    ),
                                    const SizedBox(width: 10),
                                    
                                    // Name & Status
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start, 
                                        children: [
                                          // 👑 VIP Name Widget (from home_screen.dart)
                                          VIPNameWidget(name: name, level: membershipLevel, fontSize: 16),
                                          
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
                                  ],
                                );
                              },
                            ),
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
                    
                    // 📌 MULTIPLE PINNED MESSAGE CAROUSEL (IMPROVED UI)
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('chats').doc(widget.isGroup ? widget.receiverId : (FirebaseAuth.instance.currentUser!.uid.compareTo(widget.receiverId) < 0 ? "${FirebaseAuth.instance.currentUser!.uid}_${widget.receiverId}" : "${widget.receiverId}_${FirebaseAuth.instance.currentUser!.uid}")).snapshots(),
                      builder: (context, snapshot) {
                        if(!snapshot.hasData) return const SizedBox();
                        var data = snapshot.data!.data() as Map<String, dynamic>?;
                        List pins = [];
                        if (data != null && data.containsKey('pinnedMessages')) {
                          pins = List.from(data['pinnedMessages']);
                        }
                        if(pins.isEmpty) return const SizedBox();

                        // 🟢 Validate Index & Get Current Pin
                        if (_currentPinIndex >= pins.length) _currentPinIndex = 0;
                        var currentPin = pins[_currentPinIndex];

                        return Container(
                          width: double.infinity,
                          height: 48, // Thoda sleek banaya
                          margin: const EdgeInsets.only(bottom: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E).withOpacity(0.9), 
                            border: const Border(bottom: BorderSide(color: Colors.white12))
                          ),
                          child: Row(
                            children: [
                              // 🟢 LEFT INDICATOR: SHOWS PIN COUNT
                              Container(
                                width: 45,
                                color: const Color(0xFF2575FC).withOpacity(0.2),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.push_pin, color: Color(0xFF2575FC), size: 16),
                                    Text(
                                      "${pins.length} Pin", 
                                      style: const TextStyle(color: Color(0xFF2575FC), fontSize: 9, fontWeight: FontWeight.bold)
                                    )
                                  ],
                                ),
                              ),
                              
                              // 🟢 RIGHT CONTENT: SCROLLABLE PINS
                              Expanded(
                                child: PageView.builder(
                                  itemCount: pins.length,
                                  scrollDirection: Axis.vertical, 
                                  itemBuilder: (context, index) {
                                    var pin = pins[index];
                                    return GestureDetector(
                                      onTap: () => _scrollToAndHighlight(pin['id']), 
                                      onLongPress: () => _unpinMessage(pin),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        alignment: Alignment.centerLeft,
                                        child: Row(
                                          children: [
                                            // Vertical Line Separator
                                            Container(width: 2, height: 25, color: Colors.white24),
                                            const SizedBox(width: 10),
                                            
                                            // Pin Content
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    "Pinned Message #${index + 1}", 
                                                    style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)
                                                  ),
                                                  Text(
                                                    pin['text'] ?? "", 
                                                    style: const TextStyle(color: Colors.white, fontSize: 12), 
                                                    maxLines: 1, 
                                                    overflow: TextOverflow.ellipsis
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
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
                    _currentMessagesList = messages;

                    if (_scrollController.hasClients && _scrollController.offset == _scrollController.position.maxScrollExtent) {
                       WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                    }

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

              // 🟢 INPUT AREA (UPDATED WITH LIVE VOICE)
              _isBlocked 
              ? Container(padding: const EdgeInsets.all(15), child: const Text("You blocked this user.", style: TextStyle(color: Colors.redAccent)))
              : Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Colors.black87, border: Border(top: BorderSide(color: Colors.white12))),
                  child: Row(
                    children: [
                      // 🔴 LIVE RECORDING UI
                      if (_isRecording) ...[
                        const Icon(Icons.mic, color: Colors.redAccent),
                        const SizedBox(width: 15),
                        
                        // Animated Waveform
                        Expanded(
                          child: SizedBox(
                            height: 30,
                            child: AnimatedBuilder(
                              animation: _waveController,
                              builder: (context, child) {
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(15, (index) {
                                    // Simulated random wave height based on controller value
                                    double height = 5 + (25 * (0.5 + 0.5 * (index % 2 == 0 ? _waveController.value : 1-_waveController.value))); 
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 2),
                                      width: 4,
                                      height: height,
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent, 
                                        borderRadius: BorderRadius.circular(5)
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 10),
                        // Timer (You can add real timer logic here later)
                        const Text("Recording...", style: TextStyle(color: Colors.white, fontSize: 12)),
                        const SizedBox(width: 10),
                        
                        // Stop & Send
                        GestureDetector(
                           onTap: _stopAndSendRecording,
                           child: const CircleAvatar(
                             backgroundColor: Colors.redAccent,
                             radius: 20,
                             child: Icon(Icons.send, color: Colors.white, size: 20),
                           ),
                        ),
                      ] else ...[
                        // NORMAL TEXT INPUT UI
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
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.card_giftcard, color: Colors.amber), onPressed: _sendGift),
                                  IconButton(icon: const Icon(Icons.camera_alt, color: Colors.grey), onPressed: _sendImage),
                                ],
                              ),
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

    bool isHighlighted = _highlightedMessageId == msg.messageId;

    return Dismissible(
      key: Key(msg.messageId),
      direction: DismissDirection.startToEnd,
      
      // 🟢 FIX 1: CONTROLLED SWIPE (SLIDE THRESHOLD & SNAP BACK)
      dismissThresholds: const {DismissDirection.startToEnd: 0.15}, // Thoda kam kiya taaki jaldi trigger ho
      movementDuration: const Duration(milliseconds: 100), // Fast snap back
      
      confirmDismiss: (dir) async {
        HapticFeedback.lightImpact(); 
        setState(() => _replyMessage = msg);
        return false; // Don't allow delete, just trigger reply
      },
      
      // 🟢 Background Design
      background: Container(
        color: Colors.transparent,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20), // Thoda door rakha taaki icon overlap na kare
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.blueAccent),
          child: const Icon(Icons.reply, color: Colors.white, size: 18),
        ),
      ),
      child: GestureDetector(
        onTap: () => _showMessageOptions(msg, msg.messageId), 
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          color: isHighlighted ? const Color(0xFF6A11CB).withOpacity(0.4) : Colors.transparent, 
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
                      
                      Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
                        Text(timeString, style: const TextStyle(color: Colors.white70, fontSize: 10)),
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
                  GestureDetector(
                    onTap: () => _showMessageOptions(msg, msg.messageId),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, right: 5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
                        child: Text(reactionCounts.keys.join(" "), style: const TextStyle(fontSize: 12)),
                      ),
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