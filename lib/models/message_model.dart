import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String text; // Agar image hai, toh ye URL hold karega
  final Timestamp timestamp;       // Kab bheja gaya
  final Timestamp? readTimestamp;  // 🟢 NEW: Kab padha gaya (Nullable)
  final List deletedBy;
  final String type; // 'text' or 'image'
  final bool isRead;               // 🟢 NEW: Status (Seen/Sent)

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    required this.deletedBy,
    this.type = 'text',
    this.isRead = false, // Default false (Unread) rahega
    this.readTimestamp,  // Default null rahega jab tak padha na jaye
  });

  factory Message.fromDocument(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      deletedBy: data['deletedBy'] ?? [],
      type: data['type'] ?? 'text',
      // 🟢 New Fields Mapping
      isRead: data['isRead'] ?? false,
      readTimestamp: data['readTimestamp'], // Firestore se timestamp uthayega
    );
  }
}