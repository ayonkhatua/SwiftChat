import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'package:flutter/services.dart'; // Status Bar Color ke liye

// 🟢 Background Handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Background Message Received: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 🟢 Status Bar ko Transparent karo premium look ke liye
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
    _notificationService.initNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Swift Chat Premium',
      // 🟢 NAYA PREMIUM THEME
      theme: ThemeData(
        brightness: Brightness.dark,
        // Primary Color Gradient jaisa purple
        primaryColor: const Color(0xFF6A11CB), 
        scaffoldBackgroundColor: const Color(0xFF121212), // Thoda soft black
        useMaterial3: true,
        
        // Modern Color Scheme
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6A11CB), // Purple
          secondary: Color(0xFF2575FC), // BlueAccent
          surface: Color(0xFF1E1E1E), // Card Color
          background: Color(0xFF121212),
        ),

        // Stylish App Bar
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // Glass effect ke liye transparent
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white, 
            fontSize: 22, 
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        
        // Floating Action Button Theme
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF6A11CB),
          foregroundColor: Colors.white,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}