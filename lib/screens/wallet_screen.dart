import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// 🟢 Firebase Storage Hata diya
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../services/database_service.dart';
import '../services/cloudinary_service.dart'; // 🟢 Cloudinary Service Import

class WalletScreen extends StatefulWidget {
  final int? amount;
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
                        int totalCoins = 0;
                        int giftedCoins = 0;
                        if (snapshot.hasData && snapshot.data!.exists) {
                           var data = snapshot.data!.data() as Map<String, dynamic>;
                           int purchasedCoins = data['purchasedCoins'] ?? 0;
                           giftedCoins = data['giftedCoins'] ?? 0;
                           totalCoins = purchasedCoins + giftedCoins;
                        }

                        return Column(
                          children: [
                            Container(
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
                                  const Text("Total Balance", style: TextStyle(color: Colors.white70, fontSize: 16)),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.monetization_on, color: Color(0xFFFFD700), size: 40),
                                      const SizedBox(width: 10),
                                      Text("$totalCoins", style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  const Text("SwiftCoins", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 💸 WITHDRAWAL CARD
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.greenAccent.withOpacity(0.5))
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Withdrawable Balance", style: TextStyle(color: Colors.white70)),
                                      const SizedBox(height: 5),
                                      Text("$giftedCoins Coins", style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  ElevatedButton(
                                    onPressed: giftedCoins > 0 ? () => _showWithdrawalDialog(context, giftedCoins) : null,
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black, disabledBackgroundColor: Colors.grey.withOpacity(0.3)),
                                    child: const Text("Withdraw"),
                                  )
                                ],
                              ),
                            )
                          ],
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

  // 💸 NEW: Withdrawal Dialog
  void _showWithdrawalDialog(BuildContext context, int maxAmount) {
    final upiController = TextEditingController();
    final amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.greenAccent)),
              title: const Center(child: Text("Withdraw Coins", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("You can withdraw up to $maxAmount gifted coins.\nMinimum withdrawal limit: 500 coins.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 20),
                      
                      TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Amount to Withdraw",
                          labelStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(Icons.monetization_on, color: Colors.greenAccent),
                          suffixIcon: TextButton(
                            onPressed: () => amountController.text = maxAmount.toString(),
                            child: const Text("MAX", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.greenAccent)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return "Please enter an amount";
                          int? amount = int.tryParse(value);
                          if (amount == null) return "Invalid number";
                          if (amount < 500) return "Minimum withdrawal is 500 coins";
                          if (amount > maxAmount) return "Cannot withdraw more than $maxAmount";
                          return null;
                        },
                      ),
                      const SizedBox(height: 15),

                      TextFormField(
                        controller: upiController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "UPI ID / Number",
                          labelStyle: const TextStyle(color: Colors.grey),
                          prefixIcon: const Icon(Icons.payment, color: Colors.greenAccent),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.greenAccent)),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return "Please enter your UPI ID";
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (!isProcessing)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel", style: TextStyle(color: Colors.redAccent)),
                  ),
                
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                  onPressed: isProcessing ? null : () async {
                    if (formKey.currentState!.validate()) {
                      setState(() => isProcessing = true);
                      try {
                        User? user = FirebaseAuth.instance.currentUser;
                        if (user == null) throw Exception("User not logged in");

                        int amountToWithdraw = int.parse(amountController.text);
                        String upiId = upiController.text;

                        WriteBatch batch = FirebaseFirestore.instance.batch();

                        DocumentReference requestRef = FirebaseFirestore.instance.collection('withdrawal_requests').doc();
                        batch.set(requestRef, {'userId': user.uid, 'username': user.displayName ?? "Unknown", 'amount': amountToWithdraw, 'upiId': upiId, 'status': 'pending', 'timestamp': FieldValue.serverTimestamp()});

                        DocumentReference walletRef = FirebaseFirestore.instance.collection('wallets').doc(user.uid);
                        batch.update(walletRef, {'giftedCoins': FieldValue.increment(-amountToWithdraw)});

                        await batch.commit();

                        if (context.mounted) {
                          Navigator.pop(context);
                          _showSuccessDialog(context, message: "Withdrawal request sent! Admin will process it shortly. The amount has been deducted from your withdrawable balance.");
                        }

                      } catch (e) {
                        setState(() => isProcessing = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    }
                  },
                  child: isProcessing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text("Submit Request", style: TextStyle(color: Colors.black)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 💳 MAIN LOGIC: Payment Dialog with Screenshot Upload (Cloudinary Updated)
  void _showBuyDialog(BuildContext context, String itemName, int price) {
    File? selectedImage;
    bool isUploading = false;
    double uploadProgress = 0.0;
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
                        
                        // Default fallback
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
                
                // 3. SUBMIT BUTTON (With Cloudinary Logic)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedImage == null ? Colors.grey : const Color(0xFF6A11CB),
                  ),
                  onPressed: selectedImage == null || isUploading ? null : () async {
                    setState(() => isUploading = true);
                    
                    try {
                      User? user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;

                      // 🟢 A. Upload Image to Cloudinary (Updated)
                      String? downloadUrl = await CloudinaryService().uploadFile(
                        selectedImage!,
                        onProgress: (count, total) => setState(() => uploadProgress = count / total),
                      );

                      if (downloadUrl == null) {
                        throw Exception("Image upload failed");
                      }

                      // B. Create Request in Firestore for Admin
                      await FirebaseFirestore.instance.collection('payment_requests').add({
                        'userId': user.uid,
                        'username': user.displayName ?? "Unknown",
                        'amount': price,
                        'itemName': itemName,
                        'screenshotUrl': downloadUrl, // Cloudinary URL
                        'status': 'pending', // Pending -> Approved
                        'timestamp': FieldValue.serverTimestamp(),
                      });

                      if(context.mounted) {
                        Navigator.pop(context); // Close Dialog
                        _showSuccessDialog(context);
                      }
                    } catch (e) {
                      setState(() => isUploading = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Upload Failed: $e"),
                        backgroundColor: Colors.redAccent,
                        action: SnackBarAction(label: "Retry", textColor: Colors.white, onPressed: () => Navigator.pop(context)), // User can re-submit
                      ));
                    }
                  },
                  child: isUploading 
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20, height: 20, 
                            child: CircularProgressIndicator(
                              value: uploadProgress,
                              color: Colors.white, strokeWidth: 2
                            )
                          ),
                          const SizedBox(width: 10),
                          Text("${(uploadProgress * 100).toStringAsFixed(0)}%"),
                        ],
                      )
                    : const Text("Submit Request"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showSuccessDialog(BuildContext context, {String message = "Request Sent!\n\nAdmin will verify your screenshot and add coins/plan to your account shortly."}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 50),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ],
      )
    );
  }
}