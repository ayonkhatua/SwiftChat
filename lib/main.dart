import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; 
import 'screens/splash_screen.dart'; // 🟢 1. Splash Screen Import kiya

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase Initialize karna
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🚀 OFFLINE PERSISTENCE (Speed Booster) - ✅ JAISA AAPNE KAHA, ISKO RAKHA HAI
  // Ye data ko phone me cache karta hai taaki app offline bhi chale aur fast load ho.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Swift Chat',
      theme: ThemeData(
        brightness: Brightness.dark, // Dark Theme
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: Colors.black, // Pitch Black Background
        useMaterial3: true,
      ),
      // 🟢 2. Home ko change karke SPLASH SCREEN kar diya
      // Ab pehle Logo aayega, fir wahan check hoga ki Login hai ya nahi
      home: const SplashScreen(), 
    );
  }
}