import 'package:flutter/material.dart';

// Note: Maine Firebase hata diya hai check karne ke liye
void main() {
  runApp(const MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.blue, // Agar Blue Screen dikhi, matlab App Sahi Hai!
      body: Center(
        child: Text(
          "TEST SUCCESSFUL\nApp Crash Nahi Hua!",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    ),
  ));
}
