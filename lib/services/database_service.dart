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
      // Hum har baar Firestore se check karenge taaki setting change hote hi asar dikhe
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

  // ---------------------------------------------------
  // 👻 GHOST SETTINGS HELPER (NEW)
  // ---------------------------------------------------
  Future<void> updateGhostSettings(String key, bool value) async {
    String uid = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(uid).update({key: value});
    
    // Agar Online setting change hui hai, toh Presence system refresh karo
    if (key == 'ghost_hide_online') {
      setupPresenceSystem(); 
    }
  }

  // ---------------------------------------------------
  // 💬 2. MESSAGING SYSTEM
  // ---------------------------------------------------

  Future<void> sendMessage(String receiverId, String text, String receiverName, {bool isGroup = false}) async {
    String currentUserId = _auth.currentUser!.uid;
    String currentUserName = _auth.currentUser!.displayName ?? _auth.currentUser!.email!.split('@')[0]; 
    
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

  // ---------------------------------------------------
  // 🔔 V1 NOTIFICATION LOGIC
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
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Message.fromDocument(doc))
          .where((msg) => !msg.deletedBy.contains(currentUserId))
          .toList();
    });
  }

  // ---------------------------------------------------
  // 💎 PREMIUM SYSTEM (NEW)
  // ---------------------------------------------------
  
  Future<bool> isUserPremium() async {
    String uid = _auth.currentUser!.uid;
    var doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data()!.containsKey('isPremium')) {
      return doc.data()!['isPremium'] == true;
    }
    return false; // Default FREE user
  }

  Future<void> setPremiumStatus(bool status) async {
    String uid = _auth.currentUser!.uid;
    await _firestore.collection('users').doc(uid).set({'isPremium': status}, SetOptions(merge: true));
  }

  // ---------------------------------------------------
  // 🤝 3. FRIEND SYSTEM
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

  // ---------------------------------------------------
  // ✍️ 4. TYPING INDICATOR
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
  // 📷 5. MEDIA SENDING (Image & Audio)
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

  // 🎙️ VOICE NOTE SENDING LOGIC (ADDED)
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

      // 1. Upload Audio File
      String fileName = "${DateTime.now().millisecondsSinceEpoch}.m4a";
      Reference ref = _storage.ref().child('chat_audio/$chatId/$fileName');
      File audioFile = File(filePath);
      UploadTask uploadTask = ref.putFile(audioFile, SettableMetadata(contentType: 'audio/m4a'));
      TaskSnapshot snapshot = await uploadTask;
      String audioUrl = await snapshot.ref.getDownloadURL();

      // 2. Save Message (Type: 'audio')
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

      // 3. Update Last Message
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
  // 🗑️ 6. DELETION LOGIC
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

  // ---------------------------------------------------
  // 🔔 7. USER & PROFILE
  // ---------------------------------------------------

  Future<void> saveUserToken(String token) async {
    User? user = _auth.currentUser;
    if (user == null) return;
    await _firestore.collection('users').doc(user.uid).set({'fcm_token': token}, SetOptions(merge: true));
  }

  Future<void> updateUserProfile(String name, XFile? imageFile) async {
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

    Map<String, dynamic> updateData = {'username': name};
    if (photoUrl != null) updateData['profile_pic'] = photoUrl;

    await _firestore.collection('users').doc(user.uid).update(updateData);
    await user.updateDisplayName(name);
    if (photoUrl != null) await user.updatePhotoURL(photoUrl);
  }

  Stream<DocumentSnapshot> getUserData() {
    return _firestore.collection('users').doc(_auth.currentUser!.uid).snapshots();
  }

  Future<void> markMessagesAsRead(String receiverId, {bool isGroup = false}) async {
    String currentUserId = _auth.currentUser!.uid;

    // 👻 GHOST CHECK: Kya user ne Blue Ticks chupaye hain?
    var userDoc = await _firestore.collection('users').doc(currentUserId).get();
    bool isGhostSeen = false;
    if(userDoc.exists && userDoc.data() != null) {
       isGhostSeen = userDoc.data()!['ghost_hide_seen'] ?? false;
    }

    // Agar Ghost Seen ON hai, toh function yahin rok do. Read mark mat karo.
    if (isGhostSeen) return; 

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
  // 🚫 8. BLOCK SYSTEM
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
  // 👥 9. GROUP SYSTEM
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
  // 📢 10. CHANNEL SYSTEM
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
  // 👑 11. ADMIN PANEL FUNCTIONS (ADDED)
  // ---------------------------------------------------

  // Saare Users ki List lao
  Stream<QuerySnapshot> getAllUsers() {
    return _firestore.collection('users').orderBy('timestamp', descending: true).snapshots();
  }

  // Kisi User ko Premium ya Block karna
  Future<void> adminUpdateUser(String uid, {bool? makePremium, bool? blockUser}) async {
    Map<String, dynamic> data = {};
    if (makePremium != null) data['isPremium'] = makePremium;
    if (blockUser != null) data['isBlockedByAdmin'] = blockUser;

    await _firestore.collection('users').doc(uid).update(data);
  }
}