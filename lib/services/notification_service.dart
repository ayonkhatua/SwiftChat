import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'database_service.dart';

// ⚠️ TOP-LEVEL FUNCTION
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("🌙 Background Notification: ${message.notification?.title}");
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final DatabaseService _dbService = DatabaseService();

  // 1. Initialize Everything
  Future<void> initNotifications() async {
    // A. Permission
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // B. Token
    final fcmToken = await _firebaseMessaging.getToken();
    if (fcmToken != null) {
      print("🔔 FCM Token: $fcmToken");
      await _dbService.saveUserToken(fcmToken);
    }

    // C. Setup Local Notifications
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings, 
      iOS: null 
    );

    // 🔴 FIX 1: Yahan 'settings' likhna zaroori tha
    await _localNotifications.initialize(
      settings: initSettings, // ✅ Added 'settings:' based on your error
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print("🔔 User tapped on notification: ${response.payload}");
      },
    );

    // D. Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // E. Foreground Handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("☀️ Foreground Notification: ${message.notification?.title}");
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });
  }

  // 2. Show Local Notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel', 
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    int notificationId = Random().nextInt(100000); 

    // 🔴 FIX 2: Yahan saare parameters ka naam likhna zaroori hai
    await _localNotifications.show(
      id: notificationId,                 // ✅ id: added
      title: message.notification?.title, // ✅ title: added
      body: message.notification?.body,   // ✅ body: added
      notificationDetails: platformDetails, // ✅ notificationDetails: added
      payload: message.data.toString(),
    );
  }
}