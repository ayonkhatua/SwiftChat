import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String messageId; // 🟢 NEW FIELD ADDED
  final String senderId;
  final String? senderName;
  final String receiverId;
  final String text;
  final String type;
  final Timestamp timestamp;
  final List deletedBy;
  final bool isRead;

  Message({
    required this.messageId,
    required this.senderId,
    this.senderName,
    required this.receiverId,
    required this.text,
    required this.type,
    required this.timestamp,
    required this.deletedBy,
    required this.isRead,
  });

  // Factory to convert Firestore Document -> Message Object
  factory Message.fromDocument(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Message(
      messageId: doc.id, // 🟢 FIX: Document ki ID ko 'messageId' mein daal diya
      senderId: data['senderId'] ?? "",
      senderName: data['senderName'] ?? "Unknown",
      receiverId: data['receiverId'] ?? "",
      text: data['text'] ?? "",
      type: data['type'] ?? "text",
      timestamp: data['timestamp'] ?? Timestamp.now(),
      deletedBy: data['deletedBy'] ?? [],
      isRead: data['isRead'] ?? false,
    );
  }
}