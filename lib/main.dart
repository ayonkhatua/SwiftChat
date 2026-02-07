import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart'; 
// import 'package:firebase_messaging/firebase_messaging.dart'; // 🔴 Paused
import 'screens/splash_screen.dart';
// import 'services/notification_service.dart'; // 🔴 Paused
import 'package:flutter/services.dart'; 

// 🟢 1. Global Key (Notification se screen badalne ke liye zaroori hai)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 🟢 2. Background Handler
// 🔴 Paused
// @pragma('vm:entry-point')
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp();
//   print("Background Message Received: ${message.messageId}");
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // 3. Notification Setup
  // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler); // 🔴 Paused

  // 4. Firestore Offline Settings
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 5. Realtime Database Persistence (Offline Chats)
  try {
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    FirebaseDatabase.instance.setPersistenceCacheSizeBytes(100 * 1024 * 1024); 
  } catch (e) {
    print("Realtime DB Persistence Warning: $e");
  }

  // 6. Status Bar UI (Transparent)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // final NotificationService _notificationService = NotificationService(); // 🔴 Paused

  @override
  void initState() {
    super.initState();
    // Notifications init
    // _notificationService.initNotifications(); // 🔴 Paused
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Swift Chat Premium',
      
      // 🟢 Navigator Key Jod diya (Important)
      navigatorKey: navigatorKey,

      // PREMIUM THEME
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6A11CB), 
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
        
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6A11CB), 
          secondary: Color(0xFF2575FC), 
          surface: Color(0xFF1E1E1E),
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, 
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white, 
            fontSize: 22, 
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF6A11CB),
          foregroundColor: Colors.white,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
