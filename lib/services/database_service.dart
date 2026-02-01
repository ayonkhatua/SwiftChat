import 'dart:typed_data'; // 🟢 Web Bytes Handling
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart'; // 🟢 XFile Support
import '../models/message_model.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance; 

  // ---------------------------------------------------
  // 🟢 1. PRESENCE SYSTEM (Realtime Database)
  // ---------------------------------------------------
  void setupPresenceSystem() {
    User? user = _auth.currentUser;
    if (user == null) return;

    String uid = user.uid;
    DatabaseReference userStatusRef = _rtdb.ref('/status/$uid');
    DatabaseReference connectedRef = _rtdb.ref('.info/connected');

    connectedRef.onValue.listen((event) {
      bool isConnected = event.snapshot.value as bool? ?? false;
      if (isConnected) {
        userStatusRef.set({
          'state': 'online',
          'last_changed': ServerValue.timestamp,
        });
        userStatusRef.onDisconnect().set({
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
  // 💬 2. MESSAGING SYSTEM
  // ---------------------------------------------------

  // Send Message (Text)
  Future<void> sendMessage(String receiverId, String text, String receiverName) async {
    String currentUserId = _auth.currentUser!.uid;
    String currentUserName = _auth.currentUser!.email ?? "User"; 
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatId = ids.join("_");

    // 1. Add Message
    await _firestore.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUserId,
      'receiverId': receiverId,
      'text': text,
      'type': 'text', 
      'timestamp': FieldValue.serverTimestamp(),
      'deletedBy': [],
      'isRead': false, // 🟢 Default Unread
    });

    // 2. Update Recent Chat
    await _firestore.collection('chats').doc(chatId).set({
      'participants': ids,
      'lastMessage': text,
      'lastTime': FieldValue.serverTimestamp(),
      'users': { 
        currentUserId: currentUserName, 
        receiverId: receiverName 
      }
    }, SetOptions(merge: true));
  }

  // Get Messages
  Stream<List<Message>> getMessages(String receiverId) {
    String currentUserId = _auth.currentUser!.uid;
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatId = ids.join("_");

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
  // 📜 3. RECENT CHATS & SEARCH
  // ---------------------------------------------------

  Stream<QuerySnapshot> getRecentChats() {
    String currentUserId = _auth.currentUser!.uid;
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastTime', descending: true)
        .snapshots();
  }

  Future<QuerySnapshot> searchUsers(String query) {
    return _firestore
        .collection('users')
        .where('email', isGreaterThanOrEqualTo: query)
        .where('email', isLessThan: '${query}z')
        .get();
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
    User? user = _auth.currentUser;
    if (user == null) return Stream.value(false);
    String currentUserId = user.uid;

    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatId = ids.join("_");

    return _rtdb.ref('typing/$chatId/$receiverId').onValue.map((event) {
      if (event.snapshot.value == null) return false;
      return event.snapshot.value as bool;
    });
  }

  // ---------------------------------------------------
  // 📷 5. IMAGE SENDING (WEB + MOBILE)
  // ---------------------------------------------------

  // 🟢 Changed File to XFile
  Future<void> sendImageMessage(String receiverId, XFile imageFile, String receiverName) async {
    String currentUserId = _auth.currentUser!.uid;
    String currentUserName = _auth.currentUser!.email ?? "User";
    
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatId = ids.join("_");

    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = _storage.ref().child('chat_images/$chatId/$fileName.jpg');
      
      // 🟢 Fix: Read as bytes for Web support
      Uint8List imageData = await imageFile.readAsBytes();
      UploadTask uploadTask = ref.putData(imageData, SettableMetadata(contentType: 'image/jpeg'));

      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await _firestore.collection('chats').doc(chatId).collection('messages').add({
        'senderId': currentUserId,
        'receiverId': receiverId,
        'text': downloadUrl,
        'type': 'image',
        'timestamp': FieldValue.serverTimestamp(),
        'deletedBy': [],
        'isRead': false, // 🟢 Default Unread
      });

      await _firestore.collection('chats').doc(chatId).set({
        'participants': ids,
        'lastMessage': "📷 Photo",
        'lastTime': FieldValue.serverTimestamp(),
        'users': { 
          currentUserId: currentUserName, 
          receiverId: receiverName 
        }
      }, SetOptions(merge: true));
      
    } catch (e) {
      print("Error uploading image: $e");
    }
  }

  // ---------------------------------------------------
  // 🗑️ 6. DELETION LOGIC
  // ---------------------------------------------------

  Future<void> deleteForEveryone(String receiverId, String messageId) async {
    String currentUserId = _auth.currentUser!.uid;
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatId = ids.join("_");

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  Future<void> deleteForMe(String receiverId, String messageId) async {
    String currentUserId = _auth.currentUser!.uid;
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatId = ids.join("_");

    DocumentReference docRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    await docRef.update({
      'deletedBy': FieldValue.arrayUnion([currentUserId])
    });

    DocumentSnapshot snap = await docRef.get();
    if (snap.exists) {
      List deletedBy = snap['deletedBy'] ?? [];
      if (deletedBy.length >= 2) {
        await docRef.delete();
      }
    }
  }

  // ---------------------------------------------------
  // 🔔 7. NOTIFICATION TOKEN
  // ---------------------------------------------------

  Future<void> saveUserToken(String token) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).set({
      'fcm_token': token,
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------
  // 👤 8. USER PROFILE UPDATE (WEB + MOBILE)
  // ---------------------------------------------------

  // 🟢 Changed File to XFile
  Future<void> updateUserProfile(String name, XFile? imageFile) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    String? photoUrl;

    if (imageFile != null) {
      try {
        String fileName = "profile_${user.uid}.jpg";
        Reference ref = _storage.ref().child('profile_images/$fileName');
        
        // 🟢 Fix: Read as bytes
        Uint8List imageData = await imageFile.readAsBytes();
        UploadTask uploadTask = ref.putData(imageData, SettableMetadata(contentType: 'image/jpeg'));
        
        TaskSnapshot snapshot = await uploadTask;
        photoUrl = await snapshot.ref.getDownloadURL();
      } catch (e) {
        print("Profile Image Upload Error: $e");
      }
    }

    Map<String, dynamic> updateData = {
      'username': name,
    };
    
    if (photoUrl != null) {
      updateData['profile_pic'] = photoUrl;
    }

    await _firestore.collection('users').doc(user.uid).update(updateData);
    
    await user.updateDisplayName(name);
    if (photoUrl != null) {
      await user.updatePhotoURL(photoUrl);
    }
  }

  // Get User Details Stream
  Stream<DocumentSnapshot> getUserData() {
    return _firestore.collection('users').doc(_auth.currentUser!.uid).snapshots();
  }

  // ---------------------------------------------------
  // ✅ 9. MARK AS READ (INSTAGRAM STYLE)
  // ---------------------------------------------------
  
  Future<void> markMessagesAsRead(String receiverId) async {
    String currentUserId = _auth.currentUser!.uid;
    List<String> ids = [currentUserId, receiverId];
    ids.sort();
    String chatId = ids.join("_");

    // Fetch unread messages sent by the OTHER user
    QuerySnapshot unreadMsgs = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId) // Mujhe bheje gaye
        .where('isRead', isEqualTo: false) // Jo abhi tak unread hain
        .get();

    if (unreadMsgs.docs.isEmpty) return; // Agar sab read hai to kuch mat karo

    WriteBatch batch = _firestore.batch();

    for (var doc in unreadMsgs.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readTimestamp': FieldValue.serverTimestamp(), // Seen time save karo
      });
    }

    await batch.commit();
  }
}