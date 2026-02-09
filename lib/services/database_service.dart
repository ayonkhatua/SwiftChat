import 'dart:io'; // 🟢 ZAROORI: File Handling ke liye
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart'; 
import 'package:flutter/services.dart'; 
import '../models/message_model.dart';
import 'cloudinary_service.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; 

  // ---------------------------------------------------
  // 🟢 1. PRESENCE SYSTEM (UPDATED FOR GHOST MODE 👻)
  // ---------------------------------------------------
  void setupPresenceSystem() {
    User? user = _auth.currentUser;
    if (user == null) return;

    String uid = user.uid;
    DatabaseReference userStatusRef = _rtdb.ref('/status/$uid');
    DatabaseReference connectedRef = _rtdb.ref('.info/connected');

    connectedRef.onValue.listen((event) async {
      bool isConnected = event.snapshot.value as bool? ?? false;
      
      // 👻 GHOST CHECK: Kya user ne Online Status chupaya hai?
      var doc = await _firestore.collection('users').doc(uid).get();
      bool isGhostOnline = false;
      
      if (doc.exists && doc.data() != null) {
        isGhostOnline = doc.data()!['ghost_hide_online'] ?? false;
      }

      if (isConnected && !isGhostOnline) {
        // Normal User: Online dikhao
        userStatusRef.set({
          'state': 'online',
          'last_changed': ServerValue.timestamp,
        });
        userStatusRef.onDisconnect().set({
          'state': 'offline',
          'last_changed': ServerValue.timestamp,
        });
      } else {
        // Ghost User: Hamesha Offline dikhao
        userStatusRef.set({
          'state': 'offline',
          'last_changed': ServerValue.timestamp,
        });
      }
    });
  }

  Stream<DatabaseEvent> getUserStatus(String uid) {
    return _rtdb.ref('/status/$uid').onValue;
  }

  // 👻 GHOST SETTINGS HELPER
  Future<void> updateGhostSettings(String key, bool value) async {
    String uid = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(uid).update({key: value});
    if (key == 'ghost_hide_online') {
      setupPresenceSystem(); 
    }
  }

  // ---------------------------------------------------
  // 💰 2. WALLET & COIN SYSTEM (NEW)
  // ---------------------------------------------------

  // Wallet Balance Stream
  Stream<DocumentSnapshot> getUserWallet() {
    return _firestore.collection('users').doc(_auth.currentUser!.uid).snapshots();
  }

  // Coins Update (Add/Subtract)
  Future<void> updateSwiftCoins(String uid, int amount) async {
    await _firestore.collection('users').doc(uid).update({
      'swiftCoins': FieldValue.increment(amount)
    });
  }

  // ---------------------------------------------------
  // 🏆 3. PREMIUM LIMITS CHECKER (NEW)
  // ---------------------------------------------------
  
  Future<Map<String, dynamic>> getUserLimits() async {
    String uid = _auth.currentUser!.uid;
    var doc = await _firestore.collection('users').doc(uid).get();
    
    bool isPremium = doc.data()?['isPremium'] ?? false;
    String plan = doc.data()?['planType'] ?? "Free"; // 'Super-Premium' or 'Premium'

    if (plan == "Super-Premium") {
      return {"pinLimit": 100, "bioLimit": 500, "msgLimit": 2000, "isGhost": true, "maxFileSize": 200 * 1024 * 1024};
    } else if (isPremium) {
      return {"pinLimit": 20, "bioLimit": 100, "msgLimit": 1000, "isGhost": false, "maxFileSize": 50 * 1024 * 1024};
    } else {
      return {"pinLimit": 5, "bioLimit": 50, "msgLimit": 500, "isGhost": false, "maxFileSize": 10 * 1024 * 1024};
    }
  }

  // ---------------------------------------------------
  // 💬 4. MESSAGING SYSTEM
  // ---------------------------------------------------

  Future<void> sendMessage(String receiverId, String text, String receiverName, {bool isGroup = false, Map<String, dynamic>? replyTo}) async {
    String currentUserId = _auth.currentUser!.uid;
    String currentUserName = _auth.currentUser!.displayName ?? "User"; 
    
    String chatId;
    if (isGroup) {
      chatId = receiverId;
    } else {
      List<String> ids = [currentUserId, receiverId];
      ids.sort();
      chatId = ids.join("_");
    }

    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUserId,
      'senderName': currentUserName,
      'receiverId': receiverId,
      'text': text,
      'type': 'text', 
      'timestamp': FieldValue.serverTimestamp(),
      'deletedBy': [],
      'isRead': false,
      'reactions': {}, // Default empty
      'replyTo': replyTo, // 🟢 Reply Data Support
    });

    await _firestore.collection('chats').doc(chatId).set({
      'lastMessage': text,
      'lastTime': FieldValue.serverTimestamp(),
      if (!isGroup) 'participants': [currentUserId, receiverId],
      if (!isGroup) 'users': { 
        currentUserId: currentUserName, 
        receiverId: receiverName 
      }
    }, SetOptions(merge: true));

    if (!isGroup) {
      await sendPushNotification(receiverId, currentUserName, text);
    }
  }

  Future<void> updateChatTheme(String chatId, String themeId) async {
    await _firestore.collection('chats').doc(chatId).set({
      'themeId': themeId
    }, SetOptions(merge: true));
  }

  // ❤️ REACTION HELPER
  Future<void> toggleReaction(String chatId, String messageId, String emoji) async {
    String currentUserId = _auth.currentUser!.uid;
    DocumentReference msgRef = _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(msgRef);
      if (!snapshot.exists) return;

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      Map<String, dynamic> reactions = data['reactions'] != null ? Map<String, dynamic>.from(data['reactions']) : {};

      if (reactions[currentUserId] == emoji) {
        reactions.remove(currentUserId);
      } else {
        reactions[currentUserId] = emoji;
      }
      transaction.update(msgRef, {'reactions': reactions});
    });
  }

  // ---------------------------------------------------
  // 🔔 5. NOTIFICATION LOGIC
  // ---------------------------------------------------
  
  Future<String> getAccessToken() async {
    final jsonString = await rootBundle.loadString('assets/service-account.json');
    final accountCredentials = ServiceAccountCredentials.fromJson(jsonDecode(jsonString));
    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    final authClient = await clientViaServiceAccount(accountCredentials, scopes);
    return authClient.credentials.accessToken.data;
  }

  Future<void> sendPushNotification(String receiverId, String title, String msg) async {
    try {
      // 🟢 MUTE CHECK: Check if receiver has muted the sender
      String currentUserId = _auth.currentUser!.uid;
      var muteCheck = await _firestore.collection('users').doc(receiverId).collection('muted_chats').doc(currentUserId).get();
      if (muteCheck.exists) return; // Notification muted

      var userDoc = await _firestore.collection('users').doc(receiverId).get();
      if (!userDoc.exists || !userDoc.data()!.containsKey('fcm_token')) {
        return;
      }
      String token = userDoc['fcm_token'];
      String accessToken = await getAccessToken();
      String projectId = 'hyper-swift-chat'; 
      final String endpoint = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final Map<String, dynamic> message = {
        'message': {
          'token': token,
          'notification': {
            'title': title,
            'body': msg,
          },
          'data': {
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'id': '1',
            'status': 'done',
            'type': 'chat'
          },
          'android': {
            'priority': 'high',
            'notification': {
                'channel_id': 'high_importance_channel'
            }
          }
        }
      };

      await http.post(
        Uri.parse(endpoint),
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(message),
      );
    } catch (e) {
      print("Notification Error: $e");
    }
  }

  Stream<List<Message>> getMessages(String receiverId, {bool isGroup = false}) {
    String currentUserId = _auth.currentUser!.uid;
    String chatId;

    if (isGroup) {
      chatId = receiverId;
    } else {
      List<String> ids = [currentUserId, receiverId];
      ids.sort();
      chatId = ids.join("_");
    }

    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Message.fromDocument(doc))
          .where((msg) {
            // 1. Check if deleted by user
            if (msg.deletedBy.contains(currentUserId)) return false;
            return true;
          })
          .toList();
    });
  }

  // ---------------------------------------------------
  // 💎 6. PREMIUM STATUS
  // ---------------------------------------------------
  
  Future<bool> isUserPremium() async {
    String uid = _auth.currentUser!.uid;
    var doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data()!.containsKey('isPremium')) {
      return doc.data()!['isPremium'] == true;
    }
    return false; // Default FREE user
  }

  // ---------------------------------------------------
  // 🤝 7. FRIEND & SEARCH SYSTEM
  // ---------------------------------------------------

  Stream<QuerySnapshot> getRecentChats() {
    String currentUserId = _auth.currentUser!.uid;
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastTime', descending: true)
        .snapshots();
  }

  Future<QuerySnapshot> searchUsersByName(String query) {
    return _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThan: '${query}z')
        .get();
  }

  Future<void> sendFriendRequest(String receiverId) async {
    String currentUserId = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(receiverId).collection('friend_requests').doc(currentUserId).set({
      'from': currentUserId,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('users').doc(currentUserId).collection('sent_requests').doc(receiverId).set({
      'to': receiverId,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelFriendRequest(String receiverId) async {
    String currentUserId = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(receiverId).collection('friend_requests').doc(currentUserId).delete();
    await _firestore.collection('users').doc(currentUserId).collection('sent_requests').doc(receiverId).delete();
  }

  Future<void> acceptFriendRequest(String senderId) async {
    String currentUserId = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(currentUserId).collection('friends').doc(senderId).set({
      'since': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('users').doc(senderId).collection('friends').doc(currentUserId).set({
      'since': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('users').doc(currentUserId).collection('friend_requests').doc(senderId).delete();
    await _firestore.collection('users').doc(senderId).collection('sent_requests').doc(currentUserId).delete();
  }

  Future<void> rejectFriendRequest(String senderId) async {
    String currentUserId = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(currentUserId).collection('friend_requests').doc(senderId).delete();
    await _firestore.collection('users').doc(senderId).collection('sent_requests').doc(currentUserId).delete();
  }

  Stream<String> getFriendshipStatus(String otherUserId) {
    String currentUserId = _auth.currentUser!.uid;
    return _firestore.collection('users').doc(currentUserId).collection('friends').doc(otherUserId).snapshots().asyncMap((friendDoc) async {
      if (friendDoc.exists) return "friends";
      var sentDoc = await _firestore.collection('users').doc(currentUserId).collection('sent_requests').doc(otherUserId).get();
      if (sentDoc.exists) return "request_sent";
      var receivedDoc = await _firestore.collection('users').doc(currentUserId).collection('friend_requests').doc(otherUserId).get();
      if (receivedDoc.exists) return "request_received";
      return "stranger";
    });
  }

  // 🟢 Get Incoming Friend Requests
  Stream<QuerySnapshot> getIncomingFriendRequests() {
    String currentUserId = _auth.currentUser!.uid;
    return _firestore.collection('users').doc(currentUserId).collection('friend_requests').snapshots();
  }

  // 🟢 Get Premium Users Showcase
  Stream<QuerySnapshot> getPremiumUsers() {
    return _firestore.collection('users')
        .where('isPremium', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots();
  }

  // ---------------------------------------------------
  // ✍️ 8. TYPING INDICATOR
  // ---------------------------------------------------

  Future<void> setTypingStatus(String receiverId, bool isTyping) async {
    User? user = _auth.currentUser;
    if (user == null) return;
    String currentUserId = user.uid;
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatId = ids.join("_");

    await _rtdb.ref('typing/$chatId/$currentUserId').set(isTyping);
  }

  Stream<bool> getTypingStatus(String receiverId) {
    String currentUserId = _auth.currentUser!.uid;
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatId = ids.join("_");

    return _rtdb.ref('typing/$chatId/$receiverId').onValue.map((event) {
      if (event.snapshot.value == null) return false;
      return event.snapshot.value as bool;
    });
  }

  // ---------------------------------------------------
  // 📷 9. MEDIA SENDING (Image & Audio)
  // ---------------------------------------------------

  Future<void> sendImageMessage(String receiverId, XFile imageFile, String receiverName, {bool isGroup = false}) async {
    String currentUserId = _auth.currentUser!.uid;
    String currentUserName = _auth.currentUser!.displayName ?? "User";
    
    String chatId;
    if (isGroup) {
      chatId = receiverId;
    } else {
      List<String> ids = [currentUserId, receiverId];
      ids.sort();
      chatId = ids.join("_");
    }

    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = _storage.ref().child('chat_images/$chatId/$fileName.jpg');
      
      Uint8List imageData = await imageFile.readAsBytes();
      UploadTask uploadTask = ref.putData(imageData, SettableMetadata(contentType: 'image/jpeg'));

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await _firestore.collection('chats').doc(chatId).collection('messages').add({
        'senderId': currentUserId,
        'senderName': currentUserName,
        'receiverId': receiverId,
        'text': downloadUrl,
        'type': 'image',
        'timestamp': FieldValue.serverTimestamp(),
        'deletedBy': [],
        'isRead': false,
        'reactions': {},
      });

      await _firestore.collection('chats').doc(chatId).set({
        'lastMessage': "📷 Photo",
        'lastTime': FieldValue.serverTimestamp(),
        if (!isGroup) 'participants': [currentUserId, receiverId],
        if (!isGroup) 'users': {currentUserId: currentUserName, receiverId: receiverName}
      }, SetOptions(merge: true));
      
    } catch (e) {
      print("Error uploading image: $e");
    }
  }

  // 🎙️ VOICE NOTE SENDING
  Future<void> sendAudioMessage(String receiverId, String filePath, String receiverName, {bool isGroup = false}) async {
    try {
      String currentUserId = _auth.currentUser!.uid;
      String currentUserName = _auth.currentUser!.displayName ?? "User";
      
      String chatId;
      if (isGroup) {
        chatId = receiverId;
      } else {
        List<String> ids = [currentUserId, receiverId];
        ids.sort();
        chatId = ids.join("_");
      }

      String fileName = "${DateTime.now().millisecondsSinceEpoch}.m4a";
      Reference ref = _storage.ref().child('chat_audio/$chatId/$fileName');
      File audioFile = File(filePath);
      UploadTask uploadTask = ref.putFile(audioFile, SettableMetadata(contentType: 'audio/m4a'));
      TaskSnapshot snapshot = await uploadTask;
      String audioUrl = await snapshot.ref.getDownloadURL();

      await _firestore.collection('chats').doc(chatId).collection('messages').add({
        'senderId': currentUserId,
        'senderName': currentUserName,
        'receiverId': receiverId,
        'text': audioUrl, 
        'type': 'audio', 
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'deletedBy': [],
        'reactions': {},
      });

      await _firestore.collection('chats').doc(chatId).set({
        'lastMessage': "🎤 Voice Message",
        'lastTime': FieldValue.serverTimestamp(),
        if (!isGroup) 'participants': [currentUserId, receiverId],
      }, SetOptions(merge: true));

    } catch (e) {
      print("Error sending audio: $e");
    }
  }

  // ---------------------------------------------------
  // 🗑️ 10. DELETION & READ RECEIPTS
  // ---------------------------------------------------

  Future<void> deleteForEveryone(String receiverId, String messageId) async {
    String currentUserId = _auth.currentUser!.uid;
    String chatId;
    if (receiverId.contains('_')) {
      chatId = receiverId;
    } else {
      List<String> ids = [currentUserId, receiverId];
      ids.sort();
      chatId = ids.join("_");
    }

    // 🟢 Fetch message to check for media before deleting from Firestore
    DocumentSnapshot doc = await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).get();
    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String type = data['type'] ?? 'text';
      String url = data['text'] ?? '';
      
      // Agar message media hai, to Cloudinary se delete karo
      if (['image', 'video', 'audio', 'document'].contains(type) && url.isNotEmpty) {
        await CloudinaryService().deleteFile(url);
      }
    }

    await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).delete();
  }

  Future<void> deleteForMe(String receiverId, String messageId) async {
    String currentUserId = _auth.currentUser!.uid;
    String chatId;
    if (receiverId.contains('_')) {
      chatId = receiverId;
    } else {
      List<String> ids = [currentUserId, receiverId];
      ids.sort();
      chatId = ids.join("_");
    }
    DocumentReference docRef = _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId);
    await docRef.update({
      'deletedBy': FieldValue.arrayUnion([currentUserId])
    });
  }

  Future<void> clearChat(String receiverId, {bool isGroup = false}) async {
    String currentUserId = _auth.currentUser!.uid;
    String chatId;
    if (isGroup) {
      chatId = receiverId;
    } else {
      List<String> ids = [currentUserId, receiverId];
      ids.sort();
      chatId = ids.join("_");
    }

    var snapshot = await _firestore.collection('chats').doc(chatId).collection('messages').get();
    
    WriteBatch batch = _firestore.batch();
    int count = 0;
    
    for (var doc in snapshot.docs) {
      List deletedBy = doc['deletedBy'] ?? [];
      if (!deletedBy.contains(currentUserId)) {
        batch.update(doc.reference, {
          'deletedBy': FieldValue.arrayUnion([currentUserId])
        });
        count++;
        
        if (count >= 499) {
          await batch.commit();
          batch = _firestore.batch();
          count = 0;
        }
      }
    }
    if (count > 0) await batch.commit();
  }

  Future<void> markMessagesAsRead(String receiverId, {bool isGroup = false}) async {
    String currentUserId = _auth.currentUser!.uid;

    // 👻 GHOST CHECK: Kya user ne Blue Ticks chupaye hain?
    var userDoc = await _firestore.collection('users').doc(currentUserId).get();
    bool isGhostSeen = false;
    if(userDoc.exists && userDoc.data() != null) {
       isGhostSeen = userDoc.data()!['ghost_hide_seen'] ?? false;
    }

    if (isGhostSeen) return; // Ghost Mode ON hai, read mark mat karo

    String chatId;
    if (isGroup) {
      chatId = receiverId;
    } else if (receiverId.contains('_')) {
      chatId = receiverId;
    } else {
      List<String> ids = [currentUserId, receiverId];
      ids.sort();
      chatId = ids.join("_");
    }

    QuerySnapshot unreadMsgs = await _firestore.collection('chats').doc(chatId).collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false).get();

    if (unreadMsgs.docs.isEmpty) return;

    WriteBatch batch = _firestore.batch();
    for (var doc in unreadMsgs.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // ---------------------------------------------------
  // 🔔 11.5 UNREAD COUNT STREAM
  // ---------------------------------------------------
  Stream<int> getUnreadCount(String chatId) {
    String currentUserId = _auth.currentUser!.uid;
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // ---------------------------------------------------
  // 🔔 11. USER & PROFILE
  // ---------------------------------------------------

  Future<void> saveUserToken(String token) async {
    User? user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({'fcm_token': token}, SetOptions(merge: true));
  }

  Future<void> updateUserProfile(String name, String bio, XFile? imageFile) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    String? photoUrl;
    if (imageFile != null) {
      try {
        String fileName = "profile_${user.uid}.jpg";
        Reference ref = _storage.ref().child('profile_images/$fileName');
        Uint8List imageData = await imageFile.readAsBytes();
        UploadTask uploadTask = ref.putData(imageData, SettableMetadata(contentType: 'image/jpeg'));
        photoUrl = await (await uploadTask).ref.getDownloadURL();
      } catch (e) { print("Profile Upload Error: $e"); }
    }

    Map<String, dynamic> updateData = {'username': name, 'bio': bio};
    if (photoUrl != null) updateData['profile_pic'] = photoUrl;

    await _firestore.collection('users').doc(user.uid).update(updateData);
    await user.updateDisplayName(name);
    if (photoUrl != null) await user.updatePhotoURL(photoUrl);
  }

  Stream<DocumentSnapshot> getUserData() {
    return _firestore.collection('users').doc(_auth.currentUser!.uid).snapshots();
  }

  // ---------------------------------------------------
  // 🚫 12. BLOCK SYSTEM
  // ---------------------------------------------------

  Future<void> blockUser(String userId) async {
    String currentUserId = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(currentUserId).collection('blocked_users').doc(userId).set({});
  }

  Future<void> unblockUser(String userId) async {
    String currentUserId = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(currentUserId).collection('blocked_users').doc(userId).delete();
  }

  Stream<bool> isUserBlocked(String userId) {
    String currentUserId = _auth.currentUser!.uid;
    return _firestore.collection('users').doc(currentUserId).collection('blocked_users').doc(userId).snapshots().map((doc) => doc.exists);
  }
  
  Future<bool> amIBlockedBy(String userId) async {
    var doc = await _firestore.collection('users').doc(userId).collection('blocked_users').doc(_auth.currentUser!.uid).get();
    return doc.exists;
  }

  // ---------------------------------------------------
  // 👥 13. GROUP SYSTEM
  // ---------------------------------------------------

  Stream<List<Map<String, dynamic>>> getMyFriends() {
    String currentUserId = _auth.currentUser!.uid;
    return _firestore.collection('users').doc(currentUserId).collection('friends').snapshots().asyncMap((snapshot) async {
      List<Map<String, dynamic>> friendsData = [];
      for (var doc in snapshot.docs) {
        var userDoc = await _firestore.collection('users').doc(doc.id).get();
        if (userDoc.exists) {
          var data = userDoc.data() as Map<String, dynamic>;
          data['uid'] = doc.id;
          friendsData.add(data);
        }
      }
      return friendsData;
    });
  }

  Future<void> createGroup(String groupName, XFile? groupIcon, List<String> memberIds) async {
    bool isPremium = await isUserPremium();
    int limit = isPremium ? 10000 : 2; 

    if ((memberIds.length + 1) > limit) {
      throw Exception("MEMBERS_LIMIT_EXCEEDED"); 
    }

    String currentUserId = _auth.currentUser!.uid;
    List<String> participants = [currentUserId, ...memberIds];
    
    DocumentReference groupRef = _firestore.collection('chats').doc(); 
    String groupId = groupRef.id;

    String? photoUrl;
    if (groupIcon != null) {
       try {
        String fileName = "group_$groupId.jpg";
        Reference ref = _storage.ref().child('group_images/$fileName');
        Uint8List imageData = await groupIcon.readAsBytes();
        UploadTask uploadTask = ref.putData(imageData, SettableMetadata(contentType: 'image/jpeg'));
        photoUrl = await (await uploadTask).ref.getDownloadURL();
      } catch (e) { print("Group Icon Error: $e"); }
    }

    await groupRef.set({
      'isGroup': true,
      'groupName': groupName,
      'groupIcon': photoUrl,
      'adminId': currentUserId,
      'participants': participants,
      'lastMessage': "Group Created",
      'lastTime': FieldValue.serverTimestamp(),
      'users': {} 
    });

    await groupRef.collection('messages').add({
      'senderId': 'system',
      'text': "$groupName group created!",
      'type': 'system',
      'timestamp': FieldValue.serverTimestamp(),
      'deletedBy': [],
      'isRead': true,
    });
  }
  
  // ---------------------------------------------------
  // 📢 14. CHANNEL SYSTEM
  // ---------------------------------------------------

  Future<void> createChannel(String name, String desc, XFile? icon) async {
    String currentUserId = _auth.currentUser!.uid;
    
    DocumentReference channelRef = _firestore.collection('chats').doc();
    String channelId = channelRef.id;

    String? photoUrl;
    if (icon != null) {
       try {
        String fileName = "channel_$channelId.jpg";
        Reference ref = _storage.ref().child('channel_images/$fileName');
        Uint8List imageData = await icon.readAsBytes();
        UploadTask uploadTask = ref.putData(imageData, SettableMetadata(contentType: 'image/jpeg'));
        photoUrl = await (await uploadTask).ref.getDownloadURL();
      } catch (e) { print("Channel Icon Error: $e"); }
    }

    await channelRef.set({
      'isGroup': true,      
      'isChannel': true,    
      'groupName': name,
      'description': desc,
      'groupIcon': photoUrl,
      'adminId': currentUserId,
      'participants': [currentUserId], 
      'memberCount': 1,     
      'hideMembers': false, 
      'lastMessage': "Channel Created",
      'lastTime': FieldValue.serverTimestamp(),
      'users': {} 
    });

    await channelRef.collection('messages').add({
      'senderId': 'system',
      'text': "Channel created. Only admin can send messages.",
      'type': 'system',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': true,
      'deletedBy': [],
    });
  }

  // ---------------------------------------------------
  // 👑 15. ADMIN PANEL FUNCTIONS
  // ---------------------------------------------------

  Stream<QuerySnapshot> getAllUsers() {
    return _firestore.collection('users').orderBy('timestamp', descending: true).snapshots();
  }

  Future<void> adminUpdateUser(String uid, {bool? makePremium, bool? blockUser}) async {
    Map<String, dynamic> data = {};
    if (makePremium != null) data['isPremium'] = makePremium;
    if (blockUser != null) data['isBlockedByAdmin'] = blockUser;
    await _firestore.collection('users').doc(uid).update(data);
  }

  // ---------------------------------------------------
  // 📸 16. STORY SYSTEM
  // ---------------------------------------------------

  Future<int> _getTodayStoryCount() async {
    String uid = _auth.currentUser!.uid;
    DateTime now = DateTime.now();
    DateTime startOfDay = DateTime(now.year, now.month, now.day);
    
    var snapshot = await _firestore.collection('stories')
        .where('uid', isEqualTo: uid)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();
    
    return snapshot.docs.length;
  }

  Future<bool> canUploadStory() async {
    String uid = _auth.currentUser!.uid;
    var userDoc = await _firestore.collection('users').doc(uid).get();
    int level = userDoc.data()?['membershipLevel'] ?? 0;
    
    if (level > 0) return true; 
    
    int count = await _getTodayStoryCount();
    return count < 5;
  }

  Future<void> uploadStory(String url, String type, {String? description, DateTime? scheduledTime}) async {
    String uid = _auth.currentUser!.uid;
    String username = _auth.currentUser!.displayName ?? "User";
    
    var userDoc = await _firestore.collection('users').doc(uid).get();
    String? profilePic = userDoc.data()?['profile_pic'];

    DateTime postTime = scheduledTime ?? DateTime.now();

    await _firestore.collection('stories').add({
      'uid': uid,
      'username': username,
      'profile_pic': profilePic,
      'url': url,
      'type': type,
      'description': description,
      'timestamp': Timestamp.fromDate(postTime),
      'expiresAt': Timestamp.fromDate(postTime.add(const Duration(hours: 24))),
    });
  }

  Stream<QuerySnapshot> getActiveStories() {
    return _firestore.collection('stories')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .where('timestamp', isLessThanOrEqualTo: Timestamp.now()) // Scheduled check
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ---------------------------------------------------
  // 🟢 17. STORY REPLY SYSTEM
  // ---------------------------------------------------

  Future<void> replyToStory(String receiverId, String text, String storyUrl, String storyId, Timestamp expiresAt) async {
    String currentUserId = _auth.currentUser!.uid;
    String currentUserName = _auth.currentUser!.displayName ?? "User";
    
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatId = ids.join("_");

    // Fetch story owner info for context
    var receiverDoc = await _firestore.collection('users').doc(receiverId).get();
    String receiverName = receiverDoc.data()?['username'] ?? "User";
    String? receiverPic = receiverDoc.data()?['profile_pic'];

    // 1. Add Message to Subcollection
    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUserId,
      'senderName': currentUserName,
      'receiverId': receiverId,
      'text': text,
      'type': 'story_reply', 
      'timestamp': FieldValue.serverTimestamp(),
      'deletedBy': [],
      'isRead': false,
      'reactions': {},
      'storyReply': {
        'url': storyUrl,
        'storyId': storyId,
        'expiresAt': expiresAt,
        'username': receiverName,
        'profile_pic': receiverPic,
        'uid': receiverId,
      }
    });

    // 2. Update Chat Document
    await _firestore.collection('chats').doc(chatId).set({
      'lastMessage': "Replied to story: $text",
      'lastTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------
  // 🚩 18. REPORT SYSTEM
  // ---------------------------------------------------

  Future<void> reportUser(String reportedUserId, String reason) async {
    String currentUserId = _auth.currentUser!.uid;
    String currentUserName = _auth.currentUser!.displayName ?? "User";

    await _firestore.collection('reports').add({
      'reporterId': currentUserId,
      'reporterName': currentUserName,
      'reportedUserId': reportedUserId,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  // ---------------------------------------------------
  // 📊 19. POLL SYSTEM
  // ---------------------------------------------------

  Future<void> sendPollMessage(String receiverId, String question, List<String> options, String receiverName, {bool isGroup = false}) async {
    String currentUserId = _auth.currentUser!.uid;
    String currentUserName = _auth.currentUser!.displayName ?? "User";
    
    String chatId;
    if (isGroup) {
      chatId = receiverId;
    } else {
      List<String> ids = [currentUserId, receiverId];
      ids.sort();
      chatId = ids.join("_");
    }

    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUserId,
      'senderName': currentUserName,
      'receiverId': receiverId,
      'text': "📊 Poll: $question",
      'type': 'poll',
      'timestamp': FieldValue.serverTimestamp(),
      'deletedBy': [],
      'isRead': false,
      'reactions': {},
      'pollData': {
        'question': question,
        'options': options,
        'votes': {}, // Map<UserId, OptionIndex>
      }
    });

    await _firestore.collection('chats').doc(chatId).set({
      'lastMessage': "📊 Poll: $question",
      'lastTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> voteOnPoll(String chatId, String messageId, int optionIndex) async {
    String currentUserId = _auth.currentUser!.uid;
    DocumentReference msgRef = _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId);

    await _firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(msgRef);
      if (!snapshot.exists) return;
      
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      Map<String, dynamic> pollData = Map<String, dynamic>.from(data['pollData'] ?? {});
      Map<String, dynamic> votes = Map<String, dynamic>.from(pollData['votes'] ?? {});

      // Toggle vote (if clicking same option, remove vote. If different, switch vote)
      if (votes[currentUserId] == optionIndex) {
        votes.remove(currentUserId);
      } else {
        votes[currentUserId] = optionIndex;
      }

      pollData['votes'] = votes;
      transaction.update(msgRef, {'pollData': pollData});
    });
  }

  // ---------------------------------------------------
  // 🕒 20. SCHEDULED MESSAGES
  // ---------------------------------------------------

  Future<void> scheduleMessage(String receiverId, String text, String receiverName, DateTime scheduledTime, {bool isGroup = false}) async {
    String currentUserId = _auth.currentUser!.uid;
    String currentUserName = _auth.currentUser!.displayName ?? "User";
    
    String chatId;
    if (isGroup) {
      chatId = receiverId;
    } else {
      List<String> ids = [currentUserId, receiverId];
      ids.sort();
      chatId = ids.join("_");
    }

    await _firestore.collection('chats').doc(chatId).collection('scheduled_messages').add({
      'senderId': currentUserId,
      'senderName': currentUserName,
      'receiverId': receiverId,
      'text': text,
      'type': 'text',
      'scheduledAt': Timestamp.fromDate(scheduledTime),
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  // 🟢 Get Scheduled Messages
  Stream<QuerySnapshot> getScheduledMessages(String receiverId, {bool isGroup = false}) {
    String currentUserId = _auth.currentUser!.uid;
    String chatId;
    if (isGroup) {
      chatId = receiverId;
    } else {
      List<String> ids = [currentUserId, receiverId];
      ids.sort();
      chatId = ids.join("_");
    }

    return _firestore.collection('chats').doc(chatId).collection('scheduled_messages')
        .where('senderId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .orderBy('scheduledAt', descending: false)
        .snapshots();
  }

  // 🟢 Cancel Scheduled Message
  Future<void> cancelScheduledMessage(String receiverId, String docId, {bool isGroup = false}) async {
    String currentUserId = _auth.currentUser!.uid;
    String chatId;
    if (isGroup) {
      chatId = receiverId;
    } else {
      List<String> ids = [currentUserId, receiverId];
      ids.sort();
      chatId = ids.join("_");
    }
    await _firestore.collection('chats').doc(chatId).collection('scheduled_messages').doc(docId).delete();
  }

  // ---------------------------------------------------
  // 🎭 21. STICKER SYSTEM
  // ---------------------------------------------------

  Future<void> sendStickerMessage(String receiverId, String stickerUrl, String receiverName, {bool isGroup = false}) async {
    String currentUserId = _auth.currentUser!.uid;
    String currentUserName = _auth.currentUser!.displayName ?? "User";
    
    String chatId;
    if (isGroup) {
      chatId = receiverId;
    } else {
      List<String> ids = [currentUserId, receiverId];
      ids.sort();
      chatId = ids.join("_");
    }

    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUserId,
      'senderName': currentUserName,
      'receiverId': receiverId,
      'text': stickerUrl,
      'type': 'sticker',
      'timestamp': FieldValue.serverTimestamp(),
      'deletedBy': [],
      'isRead': false,
      'reactions': {},
    });

    await _firestore.collection('chats').doc(chatId).set({
      'lastMessage': "🎭 Sticker",
      'lastTime': FieldValue.serverTimestamp(),
      if (!isGroup) 'participants': [currentUserId, receiverId],
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------
  // 🔕 22. MUTE SYSTEM
  // ---------------------------------------------------

  Future<void> muteChat(String chatId) async {
    String currentUserId = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(currentUserId).collection('muted_chats').doc(chatId).set({});
  }

  Future<void> unmuteChat(String chatId) async {
    String currentUserId = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(currentUserId).collection('muted_chats').doc(chatId).delete();
  }

  Stream<bool> isChatMuted(String chatId) {
    String currentUserId = _auth.currentUser!.uid;
    return _firestore.collection('users').doc(currentUserId).collection('muted_chats').doc(chatId).snapshots().map((doc) => doc.exists);
  }
}