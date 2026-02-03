import 'package:flutter/material.dart';
import 'dart:ui'; // ImageFilter ke liye zaroori hai

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 🟢 FIX 1: Blur Logic Changed (Ab BoxShadow use kiya hai glow ke liye)
          // Purple Glow (Top Left)
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              height: 200, width: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purpleAccent.withOpacity(0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purpleAccent.withOpacity(0.6),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          
          // Blue Glow (Bottom Right)
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              height: 200, width: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.6),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          // Main Content (Glass Effect ke upar)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: SafeArea(
              child: Column(
                children: [
                  // Close Button
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),

                  const SizedBox(height: 20),
                  
                  // Crown Icon & Title
                  const Icon(Icons.workspace_premium, size: 80, color: Colors.amberAccent),
                  const SizedBox(height: 10),
                  const Text("SwiftChat Premium", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const Text("Unlock the full power!", style: TextStyle(color: Colors.grey, fontSize: 16)),

                  const SizedBox(height: 40),

                  // Features List
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _buildFeatureTile(Icons.groups, "Unlimited Members", "Add up to 1 Million members in channels."),
                        _buildFeatureTile(Icons.verified, "Gold Badge", "Get a verified Golden Tick on your profile."),
                        // 🟢 FIX 2: Icons.4k -> Icons.four_k
                        _buildFeatureTile(Icons.four_k, "4K Quality", "Send photos and videos in original quality."),
                        _buildFeatureTile(Icons.block, "No Ads", "Experience a completely ad-free chat."),
                      ],
                    ),
                  ),

                  // Buy Button
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: ElevatedButton(
                      onPressed: () {
                        // Payment Gateway Logic yahan aayega
                        // Abhi ke liye bas snackbar dikha dete hain
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Payment Gateway Coming Soon!"))
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amberAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 10,
                        shadowColor: Colors.amber.withOpacity(0.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Get Premium - ₹99/mo", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1), // Glass effect tile
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: Colors.amberAccent, size: 30),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}