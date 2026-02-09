import 'package:cloud_firestore/cloud_firestore.dart';

class TimeService {
  // Timestamp ko readable string mein convert karne ke liye function
  static String formatTime(Timestamp? timestamp) {
    if (timestamp == null) return "";

    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();

    // Check agar aaj ka message hai
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return _formatHourMinute(date);
    }

    // Check agar kal ka message hai
    DateTime yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return "Yesterday";
    }

    // Purana message (Date return karo)
    return "${date.day}/${date.month}/${date.year}";
  }

  // Helper to format HH:MM AM/PM manually (No extra package needed)
  static String _formatHourMinute(DateTime date) {
    String period = date.hour >= 12 ? "PM" : "AM";
    int hour = date.hour > 12 ? date.hour - 12 : date.hour;
    hour = hour == 0 ? 12 : hour; // 0 hour ko 12 banana
    
    String minute = date.minute.toString().padLeft(2, '0'); // 5 -> 05
    
    return "$hour:$minute $period";
  }
}