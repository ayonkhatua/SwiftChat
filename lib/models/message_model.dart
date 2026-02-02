import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String? id;
  final String senderId;
  final String? senderName; // 🆕 Added
  final String receiverId;
  final String text;
  final String type;
  final Timestamp timestamp;
  final List deletedBy;
  final bool isRead;

  Message({
    this.id,
    required this.senderId,
    this.senderName, // 🆕
    required this.receiverId,
    required this.text,
    required this.type,
    required this.timestamp,
    required this.deletedBy,
    required this.isRead,
  });

  factory Message.fromDocument(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'User', // 🆕
      receiverId: data['receiverId'] ?? '',
      text: data['text'] ?? '',
      type: data['type'] ?? 'text',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      deletedBy: data['deletedBy'] ?? [],
      isRead: data['isRead'] ?? false,
    );
  }
}