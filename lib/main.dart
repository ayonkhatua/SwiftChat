import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// 🟢 Global Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // 🛡️ CRASH CATCHER ZONE STARTS
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. Error Widget Setup (Crash ki jagah ye Lal Screen dikhegi)
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.red.shade900,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.yellow, size: 50),
                  const SizedBox(height: 10),
                  const Text("CRASH ERROR:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                    details.exception.toString(),
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Stack Trace:\n${details.stack.toString().split('\n').take(3).join('\n')}",
                    style: const TextStyle(color: Colors.yellow, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    };

    // 2. Firebase Init with Try-Catch
    try {
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: "AIzaSyCWVpgKw9LVr34r7JvxEzycelBtrI7lkEI",
            authDomain: "hyper-swift-chat.firebaseapp.com",
            databaseURL: "https://hyper-swift-chat-default-rtdb.asia-southeast1.firebasedatabase.app",
            projectId: "hyper-swift-chat",
            storageBucket: "hyper-swift-chat.firebasestorage.app",
            messagingSenderId: "772140616954",
            appId: "1:772140616954:web:6b2db1a880b3d531b60d43",
            measurementId: "G-99GQY8T4Q2",
          ),
        );
      } else {
        await Firebase.initializeApp();
      }
    } catch (e) {
      // Agar Firebase fail hua, toh ye print hoga
      runApp(ErrorApp(error: "Firebase Init Failed: $e"));
      return;
    }

    // 3. Offline Settings (Mobile Only)
    if (!kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      try {
        FirebaseDatabase.instance.setPersistenceEnabled(true);
      } catch (e) {
        print("Persistence Error: $e");
      }
    }

    // 4. UI Overlay
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    runApp(const MyApp());
    
  }, (error, stack) {
    // Agar koi aur error aaya toh wo yahan pakda jayega
    runApp(ErrorApp(error: "Async Error: $error"));
  });
}

// 🟢 ERROR DIKHANE WALA APP
class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.blue.shade900,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              error,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

// 🟢 AAPKA MAIN APP
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Swift Chat Premium',
      navigatorKey: navigatorKey,
      theme: ThemeData.dark(),
      home: const Scaffold(
        body: Center(child: Text("App Loaded Successfully! 🎉")),
      ),
    );
  }
}
