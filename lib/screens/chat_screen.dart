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
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/database_service.dart';
import '../models/message_model.dart';
import 'wallet_screen.dart';
import '../services/cloudinary_service.dart';
import 'home_screen.dart'; 
import 'story_view_screen.dart'; // 🟢 Added for viewing stories from chat
import 'scheduled_messages_screen.dart'; // 🟢 Added for Scheduled Messages

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
  final CloudinaryService _cloudinaryService = CloudinaryService(); // 🟢 Cloudinary Instance
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottomBtn = false;
  
  // Audio State
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _currentlyPlayingUrl;
  bool _isPlaying = false;
  Timer? _recordTimer;
  int _recordDuration = 0;
  
  // UI State
  bool _isTyping = false;
  String? _wallpaperImage;
  String _currentThemeId = 'default'; // 🟢 Chat Theme State
  bool _isBlocked = false;
  bool _isMuted = false; // 🔕 Mute State

  // 🟢 Search State
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // 🟢 Selection Mode State
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};
  
  // Reply, Edit & Highlight State
  Message? _replyMessage;
  Message? _editingMessage;
  String? _highlightedMessageId; 
  String? _deletingMessageId; 

  // 🔍 Pin Scroll Logic Helper
  List<Message> _currentMessagesList = []; 

  int _currentPinIndex = 0; // 🟢 Added for Telegram-style Pin Looping

  // 🎭 Sample Stickers List
  final List<String> _stickerList = [
    "https://cdn-icons-png.flaticon.com/512/4712/4712035.png", // Happy
    "https://cdn-icons-png.flaticon.com/512/4712/4712009.png", // Love
    "https://cdn-icons-png.flaticon.com/512/4712/4712109.png", // Cool
    "https://cdn-icons-png.flaticon.com/512/4712/4712027.png", // Sad
    "https://cdn-icons-png.flaticon.com/512/4712/4712139.png", // Angry
    "https://cdn-icons-png.flaticon.com/512/4712/4712066.png", // Laugh
    "https://cdn-icons-png.flaticon.com/512/1933/1933691.png", // Party
    "https://cdn-icons-png.flaticon.com/512/742/742751.png",   // Wink
  ];

  //  Animation Controller for Voice Wave
  late AnimationController _waveController;

  // 🟢 Stream Subscriptions (Professional Memory Management)
  StreamSubscription? _blockSubscription;
  StreamSubscription? _muteSubscription;
  StreamSubscription? _playerSubscription;

  @override
  void initState() {
    super.initState();
    if (!widget.isGroup) _checkBlockStatus();
    _checkMuteStatus(); // 🟢 Check Mute Status
    _dbService.markMessagesAsRead(widget.receiverId);
    
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        if (_scrollController.offset > 300 && !_showScrollToBottomBtn) {
          setState(() => _showScrollToBottomBtn = true);
        } else if (_scrollController.offset <= 300 && _showScrollToBottomBtn) {
          setState(() => _showScrollToBottomBtn = false);
        }
      }
    });

    _messageController.addListener(() {
      setState(() {
        _isTyping = _messageController.text.isNotEmpty;
      });
      if (!widget.isGroup) {
        _dbService.setTypingStatus(widget.receiverId, _isTyping);
      }
    });

    _playerSubscription = _audioPlayer.onPlayerComplete.listen((event) {
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
    _blockSubscription?.cancel();
    _muteSubscription?.cancel();
    _playerSubscription?.cancel();
    _recordTimer?.cancel();
    _waveController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _searchController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 🟢 LOGIC FUNCTIONS

  String get chatId => widget.isGroup 
    ? widget.receiverId 
    : (FirebaseAuth.instance.currentUser!.uid.compareTo(widget.receiverId) < 0 
        ? "${FirebaseAuth.instance.currentUser!.uid}_${widget.receiverId}" 
        : "${widget.receiverId}_${FirebaseAuth.instance.currentUser!.uid}");

  void _checkBlockStatus() {
    _blockSubscription = _dbService.isUserBlocked(widget.receiverId).listen((isBlocked) {
      if(mounted) setState(() => _isBlocked = isBlocked);
    });
  }

  void _checkMuteStatus() {
    _muteSubscription = _dbService.isChatMuted(widget.receiverId).listen((isMuted) {
      if(mounted) setState(() => _isMuted = isMuted);
    });
  }

  void _toggleMute() {
    if (_isMuted) {
      _dbService.unmuteChat(widget.receiverId);
      _showSnack("Notifications unmuted 🔔");
    } else {
      _dbService.muteChat(widget.receiverId);
      _showSnack("Notifications muted 🔕");
    }
  }

  void _toggleBlock() {
    if (_isBlocked) {
      _dbService.unblockUser(widget.receiverId);
      _showSnack("User unblocked");
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Block User?", style: TextStyle(color: Colors.white)),
          content: const Text("They won't be able to message you.", style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.pop(context);
                _dbService.blockUser(widget.receiverId);
                _showSnack("User blocked");
              },
              child: const Text("Block"),
            )
          ],
        )
      );
    }
  }

  void _showReportDialog() {
    TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Report User", style: TextStyle(color: Colors.redAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Please provide a reason for reporting this user.", style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Reason (e.g., Spam, Harassment)",
                hintStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                _dbService.reportUser(widget.receiverId, reasonController.text.trim());
                _showSnack("Report sent to Admin.");
              }
            },
            child: const Text("Report"),
          )
        ],
      )
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Clear Chat?", style: TextStyle(color: Colors.white)),
        content: const Text("This will clear all messages for you. They will remain for the other person.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              _dbService.clearChat(widget.receiverId, isGroup: widget.isGroup);
              _showSnack("Chat cleared");
            },
            child: const Text("Clear"),
          )
        ],
      )
    );
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

    Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _highlightedMessageId = null);
    });
  }

  // 🗑️ PREMIUM DELETION LOGIC
  void _confirmDeletion(Message msg, String docId) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E).withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
            side: BorderSide(color: Colors.redAccent.withOpacity(0.3), width: 2),
          ),
          title: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 40),
              ),
              const SizedBox(height: 15),
              const Text("Delete Message?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            "This message will be permanently removed from the database for everyone. This action is irreversible.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              onPressed: () async {
                Navigator.pop(context);
                
                // 🟢 Auto-Unpin Logic: Remove from pinnedMessages if deleted
                String chatId = widget.isGroup 
                    ? widget.receiverId 
                    : (FirebaseAuth.instance.currentUser!.uid.compareTo(widget.receiverId) < 0 
                        ? "${FirebaseAuth.instance.currentUser!.uid}_${widget.receiverId}" 
                        : "${widget.receiverId}_${FirebaseAuth.instance.currentUser!.uid}");

                try {
                  DocumentSnapshot chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
                  if (chatDoc.exists) {
                    List pins = (chatDoc.data() as Map<String, dynamic>)['pinnedMessages'] ?? [];
                    var pinData = pins.firstWhere((p) => p['id'] == docId, orElse: () => null);
                    if (pinData != null) {
                      await FirebaseFirestore.instance.collection('chats').doc(chatId).update({
                        'pinnedMessages': FieldValue.arrayRemove([pinData])
                      });
                    }
                  }
                } catch (e) {
                  print("Error unpinning message: $e");
                }

                setState(() => _deletingMessageId = docId);
                Future.delayed(const Duration(milliseconds: 400), () {
                  _dbService.deleteForEveryone(widget.receiverId, docId);
                  if (mounted) setState(() => _deletingMessageId = null);
                });
              },
              child: const Text("Delete for All", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0, 
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeOut
      );
    }
  }

  // 📌 SMART PIN OPTIONS
  void _showPinDurationOptions(Message msg) {
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

    // 🟢 1. Check Pin Limit (20 for Free, Unlimited for VIP)
    DocumentSnapshot chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
    List currentPins = [];
    if (chatDoc.exists && (chatDoc.data() as Map).containsKey('pinnedMessages')) {
      currentPins = (chatDoc.data() as Map)['pinnedMessages'] ?? [];
    }

    bool isPremium = await _dbService.isUserPremium();
    int limit = isPremium ? 999999 : 20; 

    if (currentPins.length >= limit) {
      _showSnack("Pin limit reached! ${isPremium ? "" : "Upgrade for unlimited."}");
      if (!isPremium) _showPremiumLockDialog();
      return;
    }

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

  // 🎨 PREMIUM CHAT THEMES
  void _showThemePicker() async {
    bool isPremium = await _dbService.isUserPremium();
    if (!isPremium) {
      _showPremiumLockDialog();
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Select Chat Theme 🎨", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 15, runSpacing: 15,
              children: [
                _themeOption("Default", 'default', Colors.purpleAccent, Colors.blueAccent),
                _themeOption("Sunset", 'sunset', const Color(0xFFFF512F), const Color(0xFFDD2476)),
                _themeOption("Ocean", 'ocean', const Color(0xFF2193b0), const Color(0xFF6dd5ed)),
                _themeOption("Gold", 'gold', const Color(0xFFFFD700), const Color(0xFFFFC107)),
                _themeOption("Royal", 'royal', const Color(0xFF141E30), const Color(0xFF243B55)),
              ],
            )
          ],
        ),
      )
    );
  }

  Widget _themeOption(String name, String id, Color c1, Color c2) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _dbService.updateChatTheme(chatId, id);
      },
      child: Column(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [c1, c2]),
              border: _currentThemeId == id ? Border.all(color: Colors.white, width: 2) : null
            ),
          ),
          const SizedBox(height: 5),
          Text(name, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Gradient? _getThemeGradient() {
    switch (_currentThemeId) {
      case 'sunset': return const LinearGradient(colors: [Color(0xFFFF512F), Color(0xFFDD2476)]);
      case 'ocean': return const LinearGradient(colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)]);
      case 'gold': return const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFC107)]);
      case 'royal': return const LinearGradient(colors: [Color(0xFF141E30), Color(0xFF243B55)]);
      default: return null;
    }
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
  Future<void> _sendMediaMessage(String url, String type, {String? fileName, String? duration}) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String chatId = widget.isGroup 
        ? widget.receiverId 
        : (user.uid.compareTo(widget.receiverId) < 0 ? "${user.uid}_${widget.receiverId}" : "${widget.receiverId}_${user.uid}");

    DocumentReference chatDoc = FirebaseFirestore.instance.collection('chats').doc(chatId);
    
    Map<String, dynamic> messageData = {
      'senderId': user.uid,
      'senderName': widget.isGroup ? (user.displayName ?? "Member") : user.displayName,
      'text': type == 'audio' && duration != null ? "$url|||$duration" : url, // 🟢 Store Duration with URL
      'type': type, // 'image' or 'audio'
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'reactions': {},
      if (fileName != null) 'fileName': fileName,
    };

    // Add to subcollection
    await chatDoc.collection('messages').add(messageData);

    // Update Last Message
    String lastMsgText = "Media";
    if (type == 'image') {
      lastMsgText = "📷 Photo";
    } else if (type == 'video') lastMsgText = "🎥 Video";
    else if (type == 'audio') lastMsgText = "🎤 Voice Note";
    else if (type == 'document') lastMsgText = "📄 Document";

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

  // 📎 ATTACHMENT MENU (WhatsApp Style)
  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(vertical: 25),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _attachmentItem(Icons.image, "Image", Colors.purple, _sendImage),
            _attachmentItem(Icons.videocam, "Video", Colors.pink, _sendVideo),
            _attachmentItem(Icons.insert_drive_file, "Document", Colors.blue, _sendDocument),
            if (widget.isGroup) _attachmentItem(Icons.poll, "Poll", Colors.orange, _showCreatePollDialog),
            _attachmentItem(Icons.emoji_emotions, "Sticker", Colors.teal, _showStickerPicker),
          ],
        ),
      ),
    );
  }

  Widget _attachmentItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 60, width: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, spreadRadius: 2)]
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // 🔄 RETRY SNACKBAR HELPER
  void _showRetrySnack(String message, VoidCallback onRetry) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.redAccent,
      action: SnackBarAction(label: "Retry", textColor: Colors.white, onPressed: onRetry),
    ));
  }

  // 🟢 Progress Dialog Helper
  void _showUploadProgressDialog(StreamController<double> progressStream) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StreamBuilder<double>(
        stream: progressStream.stream,
        initialData: 0.0,
        builder: (context, snapshot) {
          double progress = snapshot.data ?? 0.0;
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Uploading...", style: TextStyle(color: Colors.white, fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress, color: Colors.purpleAccent, backgroundColor: Colors.white10),
                const SizedBox(height: 15),
                Text("${(progress * 100).toStringAsFixed(0)}%", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        },
      ),
    );
  }

  // ️ RECORDING & AUDIO
  Future<void> _startRecording() async {
    if (_isRecording) return; // 🟢 Fix: Prevent double start crash
    
    var status = await Permission.microphone.status;
    if (status.isDenied) status = await Permission.microphone.request();

    if (status.isGranted) {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String filePath = '${appDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: filePath);
      
      // 🟢 Start Timer
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _recordDuration++);
      });

    } else if (status.isPermanentlyDenied) {
      _showSnack("Microphone permission denied. Open Settings to enable.");
      openAppSettings();
    } else {
      _showSnack("Microphone permission required!");
    }
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return; // 🟢 Fix: Prevent stop if not recording
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    if (path != null) _performAudioUpload(File(path), _formatDuration(_recordDuration));
  }

  // 🟢 Cancel Recording Logic
  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    await _audioRecorder.stop();
    // File delete logic can be added here if needed, but stopping recorder is enough usually
    setState(() => _isRecording = false);
  }

  void _performAudioUpload(File file, String duration) async {
    // 🟢 CHECK FILE SIZE LIMIT
    int size = await file.length();
    var limits = await _dbService.getUserLimits();
    if (size > limits['maxFileSize']) {
      _showSnack("File too large! Limit: ${limits['maxFileSize'] ~/ (1024*1024)}MB. Upgrade for more.");
      return;
    }

    final StreamController<double> progressController = StreamController<double>();
    _showUploadProgressDialog(progressController);

    String? url = await _cloudinaryService.uploadFile(
      file, type: 'video', // 🟢 Audio treated as video for Cloudinary
      onProgress: (count, total) => progressController.add(count / total),
    );
    
    progressController.close();
    if (mounted) Navigator.pop(context);

    if (url != null) {
      await _sendMediaMessage(url, 'audio', duration: duration);
    } else {
      _showRetrySnack("Audio Upload Failed", () => _performAudioUpload(file, duration));
    }
  }

  Future<void> _playAudio(String url) async {
    // 🟢 Handle URL with Duration (Format: url|||duration)
    String cleanUrl = url.split('|||')[0];
    try {
      if (_currentlyPlayingUrl == cleanUrl && _isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(cleanUrl));
        setState(() {
          _currentlyPlayingUrl = cleanUrl;
          _isPlaying = true;
        });
      }
    } catch (e) {
      _showSnack("Error playing audio: $e");
    }
  }

  // 🟢 Helper: Format Duration (0:00)
  String _formatDuration(int seconds) {
    int min = seconds ~/ 60;
    int sec = seconds % 60;
    return "$min:${sec.toString().padLeft(2, '0')}";
  }

  // 🖼️ FULL SCREEN MEDIA VIEWER
  void _openFullScreenMedia(Message msg) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => FullScreenMediaViewer(message: msg),
    ));
  }

  // 📄 OPEN DOCUMENT
  Future<void> _openDocument(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack("Could not open document");
    }
  }

  // 🕒 SCHEDULE MESSAGE LOGIC
  void _onSendLongPress() async {
    if (!_isTyping) return;
    String text = _messageController.text.trim();
    if (text.isEmpty) return;

    DateTime now = DateTime.now();
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6A11CB),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ), dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1E1E1E)),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF6A11CB),
                onPrimary: Colors.white,
                surface: Color(0xFF1E1E1E),
                onSurface: Colors.white,
              ),
              timePickerTheme: TimePickerThemeData(
                backgroundColor: const Color(0xFF1E1E1E),
                hourMinuteTextColor: Colors.white,
                dayPeriodTextColor: Colors.white,
                dialHandColor: const Color(0xFF6A11CB),
                dialBackgroundColor: Colors.grey[800],
              )
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null && mounted) {
        DateTime scheduledTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);

        if (scheduledTime.isBefore(now)) {
          _showSnack("Please select a future time.");
          return;
        }

        await _dbService.scheduleMessage(widget.receiverId, text, widget.receiverName, scheduledTime, isGroup: widget.isGroup);
        _messageController.clear();
        _showSnack("Message scheduled for ${scheduledTime.toString().substring(0, 16)} 🕒");
      }
    }
  }

  // � SEND MESSAGE
  void _sendMessage() async {
    String text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    // 🟢 Fix: Capture data & Clear UI immediately
    Map<String, dynamic>? replyData;
    if (_replyMessage != null) {
      replyData = {
        'text': _replyMessage!.type == 'image' ? "📷 Photo" : (_replyMessage!.type == 'audio' ? "🎤 Voice Note" : _replyMessage!.text),
        'sender': _replyMessage!.senderName,
        'id': _replyMessage!.messageId
      };
    }

    bool isEditing = _editingMessage != null;
    String? editingId = _editingMessage?.messageId;

    _messageController.clear();
    setState(() {
      _replyMessage = null;
      _editingMessage = null;
    });

    if (isEditing) {
      String currentUserId = FirebaseAuth.instance.currentUser!.uid;
      String chatId = widget.isGroup ? widget.receiverId : 
        (currentUserId.compareTo(widget.receiverId) < 0 ? "${currentUserId}_${widget.receiverId}" : "${widget.receiverId}_$currentUserId");
      
      await FirebaseFirestore.instance.collection('chats').doc(chatId)
          .collection('messages').doc(editingId).update({'text': text});
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
      replyTo: replyData,
    );

    _scrollToBottom();
  }

  void _sendImage() async {
    final ImagePicker picker = ImagePicker();
    // 🟢 Added imageQuality: 70 for compression (Faster Upload)
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null && mounted) _performImageUpload(File(image.path));
  }

  void _performImageUpload(File file) async {
    // 🟢 CHECK FILE SIZE LIMIT
    int size = await file.length();
    var limits = await _dbService.getUserLimits();
    if (size > limits['maxFileSize']) {
      _showSnack("File too large! Limit: ${limits['maxFileSize'] ~/ (1024*1024)}MB");
      return;
    }

    final StreamController<double> progressController = StreamController<double>();
    _showUploadProgressDialog(progressController);

    String? url = await _cloudinaryService.uploadFile(
      file, type: 'image',
      onProgress: (count, total) => progressController.add(count / total),
    );
    
    progressController.close();
    if (mounted) Navigator.pop(context);

    if (url != null) {
      await _sendMediaMessage(url, 'image');
    } else {
      _showRetrySnack("Image Upload Failed", () => _performImageUpload(file));
    }
  }

  void _sendVideo() async {
    final ImagePicker picker = ImagePicker();
    bool isPremium = await _dbService.isUserPremium();
    int maxSecs = isPremium ? 180 : 60;

    final XFile? video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: Duration(seconds: maxSecs),
    );
    if (video != null && mounted) {
      // 🟢 Check duration for gallery videos
      final VideoPlayerController tempController = VideoPlayerController.file(File(video.path));
      await tempController.initialize();
      if (tempController.value.duration.inSeconds > maxSecs) {
        tempController.dispose();
        _showSnack("Video must be $maxSecs seconds or less!");
      } else {
        tempController.dispose();
        _performVideoUpload(File(video.path));
      }
    }
  }

  void _performVideoUpload(File file) async {
    // 🟢 CHECK FILE SIZE LIMIT
    int size = await file.length();
    var limits = await _dbService.getUserLimits();
    if (size > limits['maxFileSize']) {
      _showSnack("File too large! Limit: ${limits['maxFileSize'] ~/ (1024*1024)}MB");
      return;
    }

    final StreamController<double> progressController = StreamController<double>();
    _showUploadProgressDialog(progressController);

    String? url = await _cloudinaryService.uploadFile(
      file, type: 'video',
      onProgress: (count, total) => progressController.add(count / total),
    );

    progressController.close();
    if (mounted) Navigator.pop(context);
    
    if (url != null) {
      await _sendMediaMessage(url, 'video');
    } else {
      _showRetrySnack("Video Upload Failed", () => _performVideoUpload(file));
    }
  }

  void _sendDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null && mounted) {
      String fileName = result.files.single.name;
      _performDocumentUpload(File(result.files.single.path!), fileName);
    }
  }

  void _performDocumentUpload(File file, String fileName) async {
    // 🟢 CHECK FILE SIZE LIMIT
    int size = await file.length();
    var limits = await _dbService.getUserLimits();
    if (size > limits['maxFileSize']) {
      _showSnack("File too large! Limit: ${limits['maxFileSize'] ~/ (1024*1024)}MB");
      return;
    }

    final StreamController<double> progressController = StreamController<double>();
    _showUploadProgressDialog(progressController);

    String? url = await _cloudinaryService.uploadFile(
      file, type: 'raw', // 🟢 Fix: Upload documents as Raw
      onProgress: (count, total) => progressController.add(count / total),
    );

    progressController.close();
    if (mounted) Navigator.pop(context);
    
    if (url != null) {
      await _sendMediaMessage(url, 'document', fileName: fileName);
    } else {
      _showRetrySnack("Document Upload Failed", () => _performDocumentUpload(file, fileName));
    }
  }

  // 📊 POLL CREATION
  void _showCreatePollDialog() {
    TextEditingController questionController = TextEditingController();
    List<TextEditingController> optionControllers = [TextEditingController(), TextEditingController()];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text("Create Poll 📊", style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: questionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: "Ask a question...", hintStyle: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(height: 15),
                  ...List.generate(optionControllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: TextField(
                        controller: optionControllers[index],
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Option ${index + 1}",
                          hintStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 16),
                        ),
                      ),
                    );
                  }),
                  if (optionControllers.length < 5)
                    TextButton.icon(
                      icon: const Icon(Icons.add, color: Colors.blueAccent),
                      label: const Text("Add Option"),
                      onPressed: () => setDialogState(() => optionControllers.add(TextEditingController())),
                    )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () {
                  String question = questionController.text.trim();
                  List<String> options = optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                  if (question.isNotEmpty && options.length >= 2) {
                    Navigator.pop(context);
                    _dbService.sendPollMessage(widget.receiverId, question, options, widget.receiverName, isGroup: widget.isGroup);
                  }
                },
                child: const Text("Create"),
              )
            ],
          );
        }
      )
    );
  }

  // 🎭 STICKER PICKER
  void _showStickerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) {
        return Container(
          height: 300,
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              const Text("Send a Sticker", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10),
                  itemCount: _stickerList.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _sendSticker(_stickerList[index]);
                      },
                      child: CachedNetworkImage(
                        imageUrl: _stickerList[index],
                        placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _sendSticker(String url) {
    _dbService.sendStickerMessage(widget.receiverId, url, widget.receiverName, isGroup: widget.isGroup);
  }

  void _toggleReaction(String docId, String emoji) {
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    String chatId = widget.isGroup 
        ? widget.receiverId 
        : (currentUserId.compareTo(widget.receiverId) < 0 ? "${currentUserId}_${widget.receiverId}" : "${widget.receiverId}_$currentUserId");

    _dbService.toggleReaction(chatId, docId, emoji);
    Navigator.pop(context); // Instant pop for better feel
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
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    String chatId = widget.isGroup 
        ? widget.receiverId 
        : (currentUserId.compareTo(widget.receiverId) < 0 ? "${currentUserId}_${widget.receiverId}" : "${widget.receiverId}_$currentUserId");
    
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
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 5),
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.transparent),
                                  child: Text(e, style: const TextStyle(fontSize: 28)),
                                ),
                              )
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                _showCustomReactionInput(docId);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
                                  child: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 24),
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
                      child: FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('chats').doc(chatId).get(),
                        builder: (context, snapshot) {
                          bool isAlreadyPinned = false;
                          Map<String, dynamic>? pinnedData;
                          
                          if (snapshot.hasData && snapshot.data!.exists) {
                            List pins = snapshot.data!.get('pinnedMessages') ?? [];
                            var existing = pins.where((p) => p['id'] == msg.messageId);
                            if (existing.isNotEmpty) {
                              isAlreadyPinned = true;
                              pinnedData = existing.first;
                            }
                          }

                          return Column(
                            children: [
                              _buildMenuItem(Icons.reply, "Reply", () { Navigator.pop(context); setState(() => _replyMessage = msg); }),
                              _buildMenuItem(Icons.copy, "Copy", () { Clipboard.setData(ClipboardData(text: msg.text)); Navigator.pop(context); _showSnack("Copied!"); }),
                              _buildMenuItem(Icons.forward, "Forward", () => _forwardMessage(msg)),
                              _buildMenuItem(
                                isAlreadyPinned ? Icons.push_pin_outlined : Icons.push_pin, 
                                isAlreadyPinned ? "Unpin Message" : "Pin Message", 
                                () { 
                                  Navigator.pop(context); 
                                  if (isAlreadyPinned) {
                                    _unpinMessage(pinnedData!);
                                  } else {
                                    _showPinDurationOptions(msg); 
                                  }
                                },
                                isDestructive: isAlreadyPinned,
                              ), 
                              _buildMenuItem(Icons.delete_outline, "Delete for me", () { 
                                Navigator.pop(context); 
                                _enterSelectionMode(initialMessageId: msg.messageId); // 🟢 Auto-select this message
                              }, isDestructive: true),
                              
                              if (msg.senderId == FirebaseAuth.instance.currentUser!.uid) ...[
                                _buildMenuItem(Icons.edit, "Edit", () { 
                                  Navigator.pop(context); 
                                  setState(() { 
                                    _editingMessage = msg; 
                                    _messageController.text = msg.text; 
                                  }); 
                                }),
                              ]
                            ],
                          );
                        }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
        content: TextField(
          controller: customEmojiController,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 30, color: Colors.white),
          decoration: const InputDecoration(
            border: InputBorder.none, 
            hintText: "Type emoji...", 
            hintStyle: TextStyle(color: Colors.grey, fontSize: 14)
          ),
          onChanged: (val) {
            String emoji = val.trim();
            if (emoji.isNotEmpty) {
              _toggleReaction(docId, emoji.characters.last);
            }
          },
        ),
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

  // 🟢 Helper: Professional Time Formatting (12-hour AM/PM)
  String _formatTime(DateTime dt) {
    String hour = (dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour)).toString();
    String minute = dt.minute.toString().padLeft(2, '0');
    String period = dt.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }

  // 🟢 Helper: Date Header Logic
  String _getDateHeader(DateTime dt) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = today.subtract(const Duration(days: 1));
    DateTime dateToCheck = DateTime(dt.year, dt.month, dt.day);

    if (dateToCheck == today) return "Today";
    if (dateToCheck == yesterday) return "Yesterday";
    
    if (now.difference(dt).inDays < 7) {
      const days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
      return days[dt.weekday - 1];
    }
    return "${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}";
  }

  // 🟢 Helper: Time Ago for Sent/Seen
  String _timeAgo(DateTime d) {
    Duration diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  // 🟢 Selection Mode Logic
  void _enterSelectionMode({String? initialMessageId}) {
    setState(() {
      _isSelectionMode = true;
      _selectedMessageIds.clear();
      if (initialMessageId != null) {
        _selectedMessageIds.add(initialMessageId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  void _toggleSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  void _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;
    
    for (String id in _selectedMessageIds) {
      await _dbService.deleteForMe(widget.receiverId, id);
    }
    
    _exitSelectionMode();
    _showSnack("Messages deleted for you");
  }

  // 🟢 NEW: Sender Side Menu (Dummy Implementation)
  void _showMyMessageMenu(Message msg) {
    bool canEdit = msg.type == 'text' && DateTime.now().difference(msg.timestamp.toDate()).inMinutes < 15;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
              ),
              if (canEdit)
                _buildMenuOption(Icons.edit, "Edit", () { 
                  Navigator.pop(context);
                  setState(() { 
                    _editingMessage = msg; 
                    _messageController.text = msg.text; 
                  }); 
                }),
              _buildMenuOption(Icons.forward, "Forward", () => _forwardMessage(msg)),
              _buildMenuOption(Icons.copy, "Copy", () { 
                Clipboard.setData(ClipboardData(text: msg.text)); 
                Navigator.pop(context);
                _showSnack("Copied!");
              }),
              _buildMenuOption(Icons.undo, "Unsend", () { 
                Navigator.pop(context);
                _confirmDeletion(msg, msg.messageId);
              }),
              _buildMenuOption(Icons.push_pin, "Pin", () { 
                Navigator.pop(context);
                _showPinDurationOptions(msg);
              }),
              _buildMenuOption(Icons.delete_outline, "Delete for me", () { 
                Navigator.pop(context); 
                _enterSelectionMode(initialMessageId: msg.messageId); // 🟢 Auto-select this message
              }, isDestructive: true),
            ],
          ),
        );
      }
    );
  }

  // 🟢 NEW: Receiver Side Menu
  void _showReceiverMessageMenu(Message msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
              ),
              _buildMenuOption(Icons.forward, "Forward", () => _forwardMessage(msg)),
              _buildMenuOption(Icons.push_pin, "Pin", () { 
                Navigator.pop(context);
                _showPinDurationOptions(msg);
              }),
              _buildMenuOption(Icons.delete_outline, "Delete for me", () { 
                Navigator.pop(context); 
                _enterSelectionMode(initialMessageId: msg.messageId); 
              }, isDestructive: true),
            ],
          ),
        );
      }
    );
  }

  Widget _buildMenuOption(IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : Colors.white),
      title: Text(label, style: TextStyle(color: isDestructive ? Colors.redAccent : Colors.white)),
      onTap: onTap,
    );
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
                      child: _isSelectionMode 
                      ? Row( // 🟢 Selection Mode Header
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: _exitSelectionMode,
                            ),
                            Expanded(
                              child: Text(
                                "${_selectedMessageIds.length} Selected",
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: _selectedMessageIds.isEmpty ? null : _deleteSelectedMessages,
                            ),
                          ],
                        )
                      : _isSearching 
                      ? Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _isSearching = false;
                                  _searchController.clear();
                                });
                              },
                            ),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(color: Colors.white),
                                autofocus: true,
                                decoration: const InputDecoration(
                                  hintText: "Search...",
                                  hintStyle: TextStyle(color: Colors.white54),
                                  border: InputBorder.none,
                                ),
                                onChanged: (val) => setState(() {}),
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => _searchController.clear())),
                          ],
                        )
                      : Row(
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
                                                    if(!statSnap.hasData || statSnap.data!.snapshot.value == null) return const SizedBox();
                                                    var val = statSnap.data!.snapshot.value as Map;
                                                    bool isOnline = val['state'] == 'online';
                                                    String statusText = "Offline";

                                                    if (isOnline) {
                                                      statusText = "Active now";
                                                    } else if (val['last_changed'] != null) {
                                                      int lastChanged = val['last_changed'];
                                                      DateTime lastActive = DateTime.fromMillisecondsSinceEpoch(lastChanged);
                                                      Duration diff = DateTime.now().difference(lastActive);

                                                      if (diff.inMinutes < 1) {
                                                        statusText = "Active just now";
                                                      } else if (diff.inMinutes < 60) statusText = "Active ${diff.inMinutes}m ago";
                                                      else if (diff.inHours < 24) statusText = "Active ${diff.inHours}h ago";
                                                      else statusText = "Active ${diff.inDays}d ago";
                                                    }
                                                    
                                                    return Text(statusText, style: TextStyle(fontSize: 12, color: isOnline ? Colors.greenAccent : Colors.grey));
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
                              PopupMenuItem(
                                value: 'block', 
                                child: Text(_isBlocked ? "Unblock" : "Block", style: TextStyle(color: _isBlocked ? Colors.greenAccent : Colors.redAccent))
                              ),
                              const PopupMenuItem(value: 'report', child: Text("Report", style: TextStyle(color: Colors.orangeAccent))),
                              const PopupMenuItem(value: 'clear', child: Text("Clear Chat", style: TextStyle(color: Colors.redAccent))),
                              const PopupMenuItem(value: 'theme', child: Text("Chat Theme 🎨", style: TextStyle(color: Colors.amberAccent))),
                              const PopupMenuItem(value: 'scheduled', child: Text("Scheduled Messages 🕒", style: TextStyle(color: Colors.blueAccent))),
                              PopupMenuItem(
                                value: 'mute', 
                                child: Text(_isMuted ? "Unmute Notifications" : "Mute Notifications", style: const TextStyle(color: Colors.white))
                              ),
                              const PopupMenuItem(value: 'search', child: Text("Search", style: TextStyle(color: Colors.white))),
                            ],
                            onSelected: (val) {
                              if (val == 'wallpaper') _pickWallpaper();
                              if (val == 'block') _toggleBlock();
                              if (val == 'report') _showReportDialog();
                              if (val == 'clear') _clearChat();
                              if (val == 'theme') _showThemePicker();
                              if (val == 'scheduled') {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ScheduledMessagesScreen(receiverId: widget.receiverId, receiverName: widget.receiverName, isGroup: widget.isGroup)));
                              }
                              if (val == 'search') setState(() => _isSearching = true);
                              if (val == 'mute') _toggleMute();
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // 📌 MULTIPLE PINNED MESSAGE CAROUSEL (IMPROVED UI)
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('chats').doc(widget.isGroup ? widget.receiverId : (FirebaseAuth.instance.currentUser!.uid.compareTo(widget.receiverId) < 0 ? "${FirebaseAuth.instance.currentUser!.uid}_${widget.receiverId}" : "${widget.receiverId}_${FirebaseAuth.instance.currentUser!.uid}")).snapshots(),
                      builder: (context, snapshot) {
                        if(!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                        var data = snapshot.data!.data() as Map<String, dynamic>?;
                        
                        // 🟢 UPDATE THEME STATE
                        if (data != null && data.containsKey('themeId') && data['themeId'] != _currentThemeId) {
                          WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _currentThemeId = data['themeId']));
                        }

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
                          child: GestureDetector(
                            onTap: () {
                              // 1. Scroll to current pin
                              _scrollToAndHighlight(currentPin['id']);
                              // 2. Show next pin in header (Looping)
                              setState(() {
                                _currentPinIndex = (_currentPinIndex + 1) % pins.length;
                              });
                            },
                            onLongPress: () => _unpinMessage(currentPin),
                            child: Row(
                              children: [
                                // 🟢 LEFT INDICATOR: SHOWS INDEX (e.g. 1/3)
                                Container(
                                  width: 45,
                                  color: const Color(0xFF2575FC).withOpacity(0.2),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.push_pin, color: Color(0xFF2575FC), size: 16),
                                      Text(
                                        "${_currentPinIndex + 1}/${pins.length}", 
                                        style: const TextStyle(color: Color(0xFF2575FC), fontSize: 9, fontWeight: FontWeight.bold)
                                      )
                                    ],
                                  ),
                              ),
                              // 🟢 RIGHT CONTENT: SINGLE PIN DISPLAY
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    alignment: Alignment.centerLeft,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          "Pinned Message", 
                                          style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)
                                        ),
                                        Text(
                                          currentPin['text'] ?? "", 
                                          style: const TextStyle(color: Colors.white, fontSize: 12), 
                                          maxLines: 1, 
                                          overflow: TextOverflow.ellipsis
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
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
                    
                    var displayMessages = _isSearching && _searchController.text.isNotEmpty
                        ? messages.where((m) => m.text.toLowerCase().contains(_searchController.text.toLowerCase())).toList()
                        : messages;

                    _currentMessagesList = displayMessages;

                    if (_scrollController.hasClients && _scrollController.offset < 100) {
                       WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                    }

                    return Stack(
                      children: [
                        ListView.builder(
                          controller: _scrollController,
                          reverse: true,
                          itemCount: displayMessages.length,
                          itemBuilder: (context, index) {
                            Message msg = displayMessages[index];
                            bool showDateHeader = false;
                            
                            if (index == displayMessages.length - 1) {
                              showDateHeader = true;
                            } else {
                              DateTime current = msg.timestamp.toDate();
                              DateTime prev = displayMessages[index + 1].timestamp.toDate();
                              if (current.year != prev.year || current.month != prev.month || current.day != prev.day) {
                                showDateHeader = true;
                              }
                            }

                            Widget messageWidget = _buildMessageItem(msg, _getThemeGradient(), isLastMessage: index == 0);

                            if (showDateHeader) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E1E1E).withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white10)
                                        ),
                                        child: Text(
                                          _getDateHeader(msg.timestamp.toDate()),
                                          style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                                  messageWidget,
                                ],
                              );
                            }
                            return messageWidget;
                          },
                        ),
                        if (_showScrollToBottomBtn)
                          Positioned(
                            bottom: 15,
                            right: 15,
                            child: GestureDetector(
                              onTap: _scrollToBottom,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E).withOpacity(0.9),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white12),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8)]
                                ),
                                child: const Icon(Icons.keyboard_arrow_down, color: Colors.purpleAccent, size: 24),
                              ),
                            ),
                          ),
                      ],
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

              // 🟢 INPUT AREA (Hidden in Selection Mode)
              (_isBlocked || _isSelectionMode)
              ? Container(padding: const EdgeInsets.all(15), child: const Text("You blocked this user.", style: TextStyle(color: Colors.redAccent)))
              : Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.black87, 
                    border: Border(top: BorderSide(color: Colors.white12))
                  ),
                  child: Row(
                    children: [
                      // 🔴 LIVE RECORDING UI
                      if (_isRecording) ...[
                        // 🟢 Delete/Cancel Button
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          onPressed: _cancelRecording,
                        ),
                        // 🟢 Timer Text
                        Text(_formatDuration(_recordDuration), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                                  IconButton(icon: const Icon(Icons.attach_file, color: Colors.grey), onPressed: _showAttachmentMenu),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        GestureDetector(
                          onTap: _isTyping ? _sendMessage : _startRecording,
                          onLongPress: _isTyping ? _onSendLongPress : null, // 🟢 Added Long Press for Scheduling
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

  Widget _buildMessageItem(Message msg, Gradient? themeGradient, {bool isLastMessage = false}) {
    bool isMe = msg.senderId == FirebaseAuth.instance.currentUser!.uid;
    DateTime dt = msg.timestamp.toDate();
    String timeString = _formatTime(dt); // 🟢 Used Professional Time Format
    Map<String, int> reactionCounts = {};
    msg.reactions.forEach((key, value) => reactionCounts[value] = (reactionCounts[value] ?? 0) + 1);

    bool isHighlighted = _highlightedMessageId == msg.messageId;
    bool isDeleting = _deletingMessageId == msg.messageId;
    bool isMedia = msg.type == 'image' || msg.type == 'video' || msg.type == 'document';
    bool isPoll = msg.type == 'poll';
    bool isSticker = msg.type == 'sticker';
    bool isVisual = msg.type == 'image' || msg.type == 'video' || msg.type == 'sticker' || msg.type == 'document'; // 🟢 Images/Videos/Stickers/Docs (No Bubble)

    Widget messageContent = Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Dismissible(
      key: Key(msg.messageId),
      direction: _isSelectionMode ? DismissDirection.none : DismissDirection.startToEnd, // 🟢 Disable swipe in selection mode
      
      // 🟢 FIX 1: CONTROLLED SWIPE (SLIDE THRESHOLD & SNAP BACK)
      dismissThresholds: const {DismissDirection.startToEnd: 0.1}, // Aur kam kiya taaki thoda sa slide karne par hi reply ho jaye
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
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(msg.messageId); // 🟢 Toggle selection
          } else if (msg.type == 'document') {
            _openDocument(msg.text);
          } else if (isMedia) {
            _openFullScreenMedia(msg);
          } else {
            // Tap action removed for text messages to keep UI clean
          }
        },
        onLongPress: () {
          if (_isSelectionMode) return; // 🟢 Disable long press in selection mode
          HapticFeedback.heavyImpact();
          if (isMe) {
            _showMyMessageMenu(msg);
          } else {
            _showReceiverMessageMenu(msg);
          }
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isDeleting ? 0.0 : 1.0,
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
                  padding: isVisual ? EdgeInsets.zero : const EdgeInsets.all(12), // 🟢 Remove padding for visuals
                  decoration: BoxDecoration(
                    gradient: (isMe && !isVisual && !isPoll) ? (themeGradient ?? const LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)])) : null,
                    color: isVisual ? Colors.transparent : (isMe && !isPoll ? null : const Color(0xFF2A2A2A)),
                    borderRadius: BorderRadius.only(topLeft: const Radius.circular(18), topRight: const Radius.circular(18), bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4), bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18)),
                    border: isVisual ? null : Border.all(color: Colors.white10),
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
                      
                      // 📸 STORY REPLY CONTEXT
                      if (msg.type == 'story_reply' && msg.storyReply != null)
                        GestureDetector(
                          onTap: () {
                            bool isExpired = DateTime.now().isAfter(msg.storyReply!['expiresAt'].toDate());
                            if (!isExpired) {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => StoryViewScreen(stories: [msg.storyReply!], initialIndex: 0)
                              ));
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black26, 
                              borderRadius: BorderRadius.circular(12), 
                              border: const Border(left: BorderSide(color: Colors.purpleAccent, width: 3))
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(imageUrl: msg.storyReply!['url'], width: 45, height: 45, fit: BoxFit.cover),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateTime.now().isAfter(msg.storyReply!['expiresAt'].toDate()) ? "Expired 🛑" : "View Story 👁️",
                                        style: TextStyle(
                                          color: DateTime.now().isAfter(msg.storyReply!['expiresAt'].toDate()) ? Colors.redAccent : Colors.purpleAccent, 
                                          fontSize: 12, 
                                          fontWeight: FontWeight.bold
                                        )
                                      ),
                                      const Text("Replied to story", style: TextStyle(color: Colors.white70, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      if (widget.isGroup && !isMe)
                        Text(msg.senderName ?? "Member", style: TextStyle(color: Colors.purpleAccent[100], fontSize: 11, fontWeight: FontWeight.bold)),

                      if (msg.type == 'image') 
                        ClipRRect(borderRadius: BorderRadius.circular(10), child: CachedNetworkImage(imageUrl: msg.text, height: 200, width: 200, fit: BoxFit.cover))
                      else if (msg.type == 'video')
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 200, height: 200, color: Colors.white10,
                                child: const Icon(Icons.videocam, color: Colors.white24, size: 50),
                              ),
                            ),
                            const CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.play_arrow, color: Colors.white),
                            )
                          ],
                        )
                      else if (msg.type == 'document')
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E).withOpacity(0.9), // Standalone file card
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12)
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.insert_drive_file, color: Colors.redAccent, size: 28),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  msg.fileName ?? "Document", 
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (msg.type == 'audio') ...[
                        // 🟢 AUDIO MESSAGE UI (Waveform + Duration)
                        Builder(
                          builder: (context) {
                            List<String> parts = msg.text.split('|||');
                            String url = parts[0];
                            String duration = parts.length > 1 ? parts[1] : "0:00";
                            bool isPlayingThis = _currentlyPlayingUrl == url && _isPlaying;

                            return Container(
                              width: 200,
                              padding: const EdgeInsets.all(5),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _playAudio(msg.text),
                                    child: Icon(isPlayingThis ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white, size: 35)
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 🟢 Visual Waveform (Simulated Bars)
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: List.generate(20, (i) => Container(
                                            width: 3,
                                            height: 10 + (i % 3 == 0 ? 10.0 : (i % 2 == 0 ? 5.0 : 15.0)), // Random-ish heights
                                            decoration: BoxDecoration(
                                              color: isPlayingThis ? Colors.white : Colors.white54,
                                              borderRadius: BorderRadius.circular(2)
                                            ),
                                          )),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(duration, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                        )
                      ]
                      else if (msg.type == 'poll' && msg.pollData != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("📊 ${msg.pollData!['question']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 10),
                            ...List.generate((msg.pollData!['options'] as List).length, (index) {
                              String option = msg.pollData!['options'][index];
                              Map votes = msg.pollData!['votes'] ?? {};
                              int voteCount = votes.values.where((v) => v == index).length;
                              int totalVotes = votes.length;
                              double percent = totalVotes == 0 ? 0 : voteCount / totalVotes;
                              bool iVoted = votes[FirebaseAuth.instance.currentUser!.uid] == index;

                              return GestureDetector(
                                onTap: () => _dbService.voteOnPoll(chatId, msg.messageId, index),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: iVoted ? Colors.blueAccent.withOpacity(0.2) : Colors.white10,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: iVoted ? Colors.blueAccent : Colors.transparent),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(option, style: const TextStyle(color: Colors.white)),
                                          if (iVoted) const Icon(Icons.check_circle, color: Colors.blueAccent, size: 16),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      LinearProgressIndicator(value: percent, color: Colors.blueAccent, backgroundColor: Colors.white10),
                                      const SizedBox(height: 2),
                                      Text("$voteCount votes (${(percent * 100).toStringAsFixed(0)}%)", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            Text("${(msg.pollData!['votes'] as Map).length} total votes", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        )
                      else if (msg.type == 'sticker')
                        CachedNetworkImage(
                          imageUrl: msg.text,
                          width: 120, height: 120,
                          fit: BoxFit.contain,
                        )
                      else 
                        Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 16)),


                      const SizedBox(height: 4),
                      
                      Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
                        Text(timeString, style: const TextStyle(color: Colors.white70, fontSize: 10)),
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
      ),
      ),
      if (isMe && isLastMessage)
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 10, bottom: 5),
          child: Text(
            "${msg.isRead ? "Seen" : "Sent"} • ${_timeAgo(dt)}",
            style: TextStyle(
              color: msg.isRead ? Colors.blueAccent : Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold
            ),
          ),
        ),
      ],
    );

    // 🟢 Wrap with Selection Checkbox
    if (_isSelectionMode) {
      return GestureDetector(
        onTap: () => _toggleSelection(msg.messageId),
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(child: AbsorbPointer(child: messageContent)), // Disable inner interactions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Icon(
                  _selectedMessageIds.contains(msg.messageId) ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: _selectedMessageIds.contains(msg.messageId) ? Colors.blueAccent : Colors.grey,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutBack,
      child: isDeleting ? const SizedBox(width: double.infinity, height: 0) : messageContent,
    );
  }
}

// 🟢 NEW: Full Screen Media Viewer Widget
class FullScreenMediaViewer extends StatefulWidget {
  final Message message;
  const FullScreenMediaViewer({super.key, required this.message});

  @override
  State<FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends State<FullScreenMediaViewer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.message.type == 'video') {
      _initVideo();
    }
  }

  void _initVideo() async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.message.text));
      await _videoController!.initialize();
      
      if (!mounted) return; // 🟢 Fix: Prevent setState after dispose
      
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        showControls: true, // 🟢 Explicitly enable controls (Play/Pause, Time)
        aspectRatio: _videoController!.value.aspectRatio,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF6A11CB),
          handleColor: const Color(0xFF2575FC),
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white54,
        ),
        placeholder: const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB))),
      );

      setState(() => _isInitialized = true);
    } catch (e) {
      print("Video Init Error: $e"); // 🟢 Fix: Handle invalid video URL crash
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.message.senderName ?? "Media", style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Center(
        child: widget.message.type == 'image'
            ? InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: widget.message.text,
                  placeholder: (context, url) => const CircularProgressIndicator(color: Color(0xFF6A11CB)),
                  errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
                ),
              )
            : _isInitialized
                ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: Chewie(controller: _chewieController!),
                  )
                : const CircularProgressIndicator(color: Color(0xFF6A11CB)),
      ),
    );
  }
}