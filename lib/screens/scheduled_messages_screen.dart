import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';

class ScheduledMessagesScreen extends StatelessWidget {
  final String receiverId;
  final String receiverName;
  final bool isGroup;

  const ScheduledMessagesScreen({
    super.key, 
    required this.receiverId, 
    required this.receiverName, 
    this.isGroup = false
  });

  @override
  Widget build(BuildContext context) {
    final DatabaseService dbService = DatabaseService();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Scheduled Messages 🕒", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: dbService.getScheduledMessages(receiverId, isGroup: isGroup),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF6A11CB)));
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No scheduled messages", style: TextStyle(color: Colors.white54)));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              DateTime scheduledAt = (data['scheduledAt'] as Timestamp).toDate();
              String timeStr = "${scheduledAt.day}/${scheduledAt.month} ${scheduledAt.hour}:${scheduledAt.minute.toString().padLeft(2, '0')}";

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white12),
                ),
                child: ListTile(
                  title: Text(data['text'], style: const TextStyle(color: Colors.white)),
                  subtitle: Text("Scheduled for: $timeStr", style: const TextStyle(color: Colors.grey)),
                  trailing: IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.redAccent),
                    onPressed: () => dbService.cancelScheduledMessage(receiverId, doc.id, isGroup: isGroup),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}