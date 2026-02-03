import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboard ke liye
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart'; // 🟢 QR Code Package
import '../services/database_service.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final DatabaseService dbService = DatabaseService();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Blobs (Premium Feel)
          Positioned(top: -100, left: -50, child: _buildBlob(const Color(0xFF6A11CB))),
          Positioned(bottom: 100, right: -50, child: _buildBlob(const Color(0xFF2575FC))),
          
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: const Text("Swift Wallet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // 💰 BALANCE CARD (Glassmorphism)
                    StreamBuilder<DocumentSnapshot>(
                      stream: dbService.getUserWallet(),
                      builder: (context, snapshot) {
                        int coins = 0;
                        if (snapshot.hasData && snapshot.data!.exists) {
                           var data = snapshot.data!.data() as Map<String, dynamic>;
                           coins = data['swiftCoins'] ?? 0;
                        }

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)]),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [BoxShadow(color: const Color(0xFF6A11CB).withOpacity(0.5), blurRadius: 20, spreadRadius: 2)],
                            border: Border.all(color: Colors.white24)
                          ),
                          child: Column(
                            children: [
                              const Text("Available Balance", style: TextStyle(color: Colors.white70, fontSize: 16)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 40),
                                  const SizedBox(width: 10),
                                  Text("$coins", style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 5),
                              const Text("SwiftCoins", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }
                    ),
                    const SizedBox(height: 30),

                    const Align(alignment: Alignment.centerLeft, child: Text("Buy Coins", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 15),

                    // 🛒 BUY OPTIONS GRID
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 15,
                        mainAxisSpacing: 15,
                        childAspectRatio: 1.2,
                        children: [
                          _buildCoinPack(context, "Starter", 100, 149, Colors.blueAccent),
                          _buildCoinPack(context, "Pro", 500, 699, Colors.purpleAccent),
                          _buildCoinPack(context, "Elite", 1200, 1499, Colors.orangeAccent),
                          _buildCoinPack(context, "Whale", 5000, 5999, Colors.redAccent),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🟣 Helper: Background Blob
  Widget _buildBlob(Color color) {
    return Container(
      height: 300, width: 300,
      decoration: BoxDecoration(
        color: color.withOpacity(0.3),
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 100, spreadRadius: 50)],
      ),
    );
  }

  // 📦 Helper: Coin Pack Card
  Widget _buildCoinPack(BuildContext context, String name, int coins, int price, Color color) {
    return GestureDetector(
      onTap: () => _showBuyDialog(context, coins, price),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.stars, color: color, size: 30),
            const SizedBox(height: 10),
            Text("$coins Coins", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text("₹$price", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  // 💳 Helper: Buy Dialog (Dynamic QR & UPI)
  void _showBuyDialog(BuildContext context, int coins, int price) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.purpleAccent)),
          title: const Center(child: Text("Scan to Pay", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Pay ₹$price for $coins Coins", style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),

              // 🟢 FETCH UPI FROM FIREBASE
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('admin_settings').doc('payment').get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator(color: Colors.purpleAccent)));
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Text("Payment System Unavailable", style: TextStyle(color: Colors.redAccent));
                  }

                  String upiId = snapshot.data!['upi_id'] ?? "admin@upi";
                  
                  // QR Data Format: upi://pay?pa=UPI_ID&pn=NAME&am=AMOUNT
                  String upiData = "upi://pay?pa=$upiId&pn=SwiftChat&am=$price&tn=Buying $coins Coins";

                  return Column(
                    children: [
                      // 🔳 QR CODE GENERATOR
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                        child: QrImageView(
                          data: upiData,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // 📋 UPI ID COPY
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white24)
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(upiId, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: upiId));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UPI ID Copied!")));
                              },
                              child: const Icon(Icons.copy, color: Colors.blueAccent, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
              ),
              
              const SizedBox(height: 20),
              const Text("After payment, send screenshot to:", style: TextStyle(color: Colors.grey, fontSize: 12)),
              const Text("+91 82501 56425", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("Cancel", style: TextStyle(color: Colors.redAccent))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A11CB)),
              onPressed: () => Navigator.pop(context),
              child: const Text("I Paid"),
            ),
          ],
        );
      },
    );
  }
}