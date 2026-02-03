import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String messageId; 
  final String senderId;
  final String? senderName;
  final String receiverId;
  final String text;
  final String type;
  final Timestamp timestamp;
  final List deletedBy;
  final bool isRead;
  final Map<String, dynamic> reactions; // 🟢 Added for Telegram Style Reactions
  final Map<String, dynamic>? replyTo;  // 🟢 Added for Reply Feature

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
    this.reactions = const {}, // Default empty map
    this.replyTo,
  });

  // Factory to convert Firestore Document -> Message Object
  factory Message.fromDocument(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Message(
      messageId: doc.id, 
      senderId: data['senderId'] ?? "",
      senderName: data['senderName'] ?? "Unknown",
      receiverId: data['receiverId'] ?? "",
      text: data['text'] ?? "",
      type: data['type'] ?? "text",
      timestamp: data['timestamp'] ?? Timestamp.now(),
      deletedBy: data['deletedBy'] ?? [],
      isRead: data['isRead'] ?? false,
      reactions: data['reactions'] ?? {}, // Firestore se reactions uthao
      replyTo: data['replyTo'], // Firestore se reply data uthao
    );
  }
}