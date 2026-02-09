import 'package:flutter/material.dart';

// 🛑 NOTE: CreateGroupScreen yahan se hata diya gaya hai 
// kyunki ab uski alag file 'create_group_screen.dart' ban gayi hai.

// ---------------------------------------------------------------------------
// 🟡 PLACEHOLDERS (Channel & Settings Abhi bhi dummy hain)
// ---------------------------------------------------------------------------

class CreateChannelScreen extends StatelessWidget {
  const CreateChannelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("New Channel", style: TextStyle(color: Colors.white)), 
        backgroundColor: Colors.black, 
        iconTheme: const IconThemeData(color: Colors.white)
      ),
      body: const Center(
        child: Text("Channel Feature Coming Soon!", style: TextStyle(color: Colors.white))
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(color: Colors.white)), 
        backgroundColor: Colors.black, 
        iconTheme: const IconThemeData(color: Colors.white)
      ),
      body: const Center(
        child: Text("Settings Feature Coming Soon!", style: TextStyle(color: Colors.white))
      ),
    );
  }
}