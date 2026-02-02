import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'database_service.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initNotifications() async {
    // 1. Permission Request
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Token Save
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      print("🔔 Device Token: $token");
      DatabaseService().saveUserToken(token);
    }

    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      DatabaseService().saveUserToken(newToken);
    });

    // 3. Local Notifications Init
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    // 🟢 ERROR FIX: Tumhara version 'settings' parameter maang raha hai
    await _localNotifications.initialize(
      settings: initSettings, // Yahan change kiya hai
      onDidReceiveNotificationResponse: (details) {
        // Handle tap
      },
    );

    // 4. Foreground Message Handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        // 🟢 ERROR FIX: Named parameters (id, title, body) add kiye hain
        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });
  }
}