import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // 🟢 Storage for Screenshot
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart'; // 🟢 Pick Image
import '../services/database_service.dart';

class WalletScreen extends StatefulWidget {
  final int? amount; // Agar direct plan se aa raha ho
  final String? planName;

  const WalletScreen({super.key, this.amount, this.planName});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final DatabaseService _dbService = DatabaseService();
  
  @override
  void initState() {
    super.initState();
    // Agar premium screen se direct redirect hoke aaya hai
    if (widget.amount != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showBuyDialog(context, "Premium Plan: ${widget.planName}", widget.amount!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Blobs
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
                    // 💰 BALANCE CARD
                    StreamBuilder<DocumentSnapshot>(
                      stream: _dbService.getUserWallet(),
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
                        childAspectRatio: 1.1,
                        children: [
                          _buildCoinPack("Starter", 100, 149, Colors.blueAccent),
                          _buildCoinPack("Pro", 500, 699, Colors.purpleAccent),
                          _buildCoinPack("Elite", 1200, 1499, Colors.orangeAccent),
                          _buildCoinPack("Whale", 5000, 5999, Colors.redAccent),
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
  Widget _buildCoinPack(String name, int coins, int price, Color color) {
    return GestureDetector(
      onTap: () => _showBuyDialog(context, "$coins SwiftCoins", price),
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

  // 💳 MAIN LOGIC: Payment Dialog with Screenshot Upload
  void _showBuyDialog(BuildContext context, String itemName, int price) {
    File? selectedImage;
    bool isUploading = false;
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.purpleAccent)),
              title: const Center(child: Text("Scan & Upload", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Pay ₹$price for $itemName", style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 15),

                    // 1. FETCH ADMIN UPI FROM FIRESTORE
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('admin_settings').doc('payment').get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const CircularProgressIndicator(color: Colors.purpleAccent);
                        
                        // Default fallback if not set in DB
                        String upiId = (snapshot.data!.data() as Map<String, dynamic>?)?['upi_id'] ?? "admin@upi";
                        String upiData = "upi://pay?pa=$upiId&pn=SwiftChat&am=$price&tn=$itemName";

                        return Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                              child: QrImageView(data: upiData, version: QrVersions.auto, size: 180.0),
                            ),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: upiId));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("UPI ID Copied!")));
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(upiId, style: const TextStyle(color: Colors.orangeAccent)),
                                  const SizedBox(width: 5),
                                  const Icon(Icons.copy, color: Colors.orangeAccent, size: 14),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                    ),

                    const SizedBox(height: 20),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 10),

                    // 2. UPLOAD SCREENSHOT SECTION
                    const Text("Upload Payment Screenshot", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    
                    GestureDetector(
                      onTap: () async {
                        final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          setState(() => selectedImage = File(image.path));
                        }
                      },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: selectedImage != null ? Colors.greenAccent : Colors.white24),
                        ),
                        child: selectedImage != null
                          ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(selectedImage!, fit: BoxFit.cover))
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_upload, color: Colors.purpleAccent, size: 30),
                                SizedBox(height: 5),
                                Text("Tap to select image", style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (!isUploading)
                  TextButton(
                    onPressed: () => Navigator.pop(context), 
                    child: const Text("Cancel", style: TextStyle(color: Colors.redAccent))
                  ),
                
                // 3. SUBMIT BUTTON
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedImage == null ? Colors.grey : const Color(0xFF6A11CB),
                  ),
                  onPressed: selectedImage == null || isUploading ? null : () async {
                    setState(() => isUploading = true);
                    
                    try {
                      User? user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;

                      // A. Upload Image to Storage
                      String fileName = "pay_${DateTime.now().millisecondsSinceEpoch}.jpg";
                      Reference ref = FirebaseStorage.instance.ref().child('payment_screenshots/$fileName');
                      await ref.putFile(selectedImage!);
                      String downloadUrl = await ref.getDownloadURL();

                      // B. Create Request in Firestore for Admin
                      await FirebaseFirestore.instance.collection('payment_requests').add({
                        'userId': user.uid,
                        'username': user.displayName ?? "Unknown",
                        'amount': price,
                        'itemName': itemName,
                        'screenshotUrl': downloadUrl,
                        'status': 'pending', // Pending -> Approved
                        'timestamp': FieldValue.serverTimestamp(),
                      });

                      if(context.mounted) {
                        Navigator.pop(context); // Close Dialog
                        _showSuccessDialog(context);
                      }
                    } catch (e) {
                      setState(() => isUploading = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                    }
                  },
                  child: isUploading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Submit Request"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 50),
        content: const Text(
          "Request Sent!\n\nAdmin will verify your screenshot and add coins/plan to your account shortly.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      )
    );
  }
}