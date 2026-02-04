import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart'; // 🟢 Added for Realtime DB
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'package:flutter/services.dart'; 

// 🟢 Background Handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Background Message Received: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // 1. Notification Setup
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🟢 2. Firestore Offline Persistence (Already Optimized)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 🟢 3. Realtime Database Offline Persistence (NEW ADDITION)
  // Ye zaroori hai taaki chats offline mode mein bhi dikhein aur send hon
  try {
    FirebaseDatabase.instance.setPersistenceEnabled(true);
    // Optional: Cache size limit (100MB) taaki device storage full na ho
    FirebaseDatabase.instance.setPersistenceCacheSizeBytes(100 * 1024 * 1024); 
  } catch (e) {
    // Agar web par run ho raha hai ya duplicate call hai to error ignore karein
    print("Realtime DB Persistence Warning: $e");
  }

  // 🟢 4. Status Bar UI
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
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    // Notifications initialize karna
    _notificationService.initNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Swift Chat Premium',
      
      // 🟢 PREMIUM THEME SETUP
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6A11CB), 
        scaffoldBackgroundColor: const Color(0xFF121212),
        useMaterial3: true,
        
        // Modern Color Scheme
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6A11CB), 
          secondary: Color(0xFF2575FC), 
          surface: Color(0xFF1E1E1E),
        ),

        // Stylish App Bar
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