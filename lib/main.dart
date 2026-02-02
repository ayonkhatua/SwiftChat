import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Error Catcher Setup
  runZonedGuarded(() async {
    await Firebase.initializeApp();
    runApp(const DebugApp());
  }, (error, stackTrace) {
    print("CRITICAL ERROR: $error");
  });
}

class DebugApp extends StatelessWidget {
  const DebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const ConnectionTester(),
      theme: ThemeData.dark(),
    );
  }
}

class ConnectionTester extends StatefulWidget {
  const ConnectionTester({super.key});

  @override
  State<ConnectionTester> createState() => _ConnectionTesterState();
}

class _ConnectionTesterState extends State<ConnectionTester> {
  String statusLog = "Initializing...\n";
  bool isError = false;

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  void _log(String message, {bool error = false}) {
    setState(() {
      statusLog += "\n$message";
      if (error) isError = true;
    });
  }

  Future<void> _testConnection() async {
    // 1. Check Firebase Init
    _log("✅ Firebase Initialized");

    // 2. Try Firestore Write
    try {
      _log("⏳ Testing Database Write...");
      await FirebaseFirestore.instance.collection('debug_test').add({
        'timestamp': FieldValue.serverTimestamp(),
        'device': 'Android Build',
      });
      _log("✅ Database Write SUCCESS! (Connection is working)");
    } catch (e) {
      _log("❌ Database Write FAILED:\n$e", error: true);
      return; // Stop if write fails
    }

    // 3. Try Firestore Read
    try {
      _log("⏳ Testing Database Read...");
      var snapshot = await FirebaseFirestore.instance.collection('debug_test').limit(1).get();
      _log("✅ Database Read SUCCESS! (Found ${snapshot.docs.length} docs)");
    } catch (e) {
      _log("❌ Database Read FAILED:\n$e", error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("🔥 Connection Tester")),
      body: Container(
        padding: const EdgeInsets.all(20),
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: SingleChildScrollView(
          child: Text(
            statusLog,
            style: TextStyle(
              color: isError ? Colors.redAccent : Colors.greenAccent,
              fontSize: 16,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}