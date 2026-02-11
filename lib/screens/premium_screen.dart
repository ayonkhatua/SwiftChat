import 'package:flutter/material.dart';
import 'dart:ui';
import 'wallet_screen.dart'; // 🟢 Wallet connect karne ke liye

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 🟢 BACKGROUND GLOWS (Static)
          Positioned(
            top: -50, left: -50,
            child: Container(
              height: 250, width: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purpleAccent.withOpacity(0.4),
                boxShadow: [BoxShadow(color: Colors.purpleAccent.withOpacity(0.5), blurRadius: 100, spreadRadius: 20)],
              ),
            ),
          ),
          Positioned(
            bottom: -50, right: -50,
            child: Container(
              height: 250, width: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amberAccent.withOpacity(0.4),
                boxShadow: [BoxShadow(color: Colors.amberAccent.withOpacity(0.5), blurRadius: 100, spreadRadius: 20)],
              ),
            ),
          ),

          // 🟢 GLASS EFFECT CONTENT
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: SafeArea(
              child: Column(
                children: [
                  // HEADER
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Premium Plans", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // SCROLLABLE PLANS
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      children: [
                        // 🟡 PLAN 1: GOLD (₹99)
                        _buildPlanCard(
                          context,
                          title: "Gold Membership",
                          price: "₹99 / month",
                          numericPrice: 99,
                          color: const Color(0xFFFFD700),
                          icon: Icons.star,
                          features: [
                            "✨ Golden Name & Border",
                            "⭐ Gold Star Badge",
                            "📌 Pin up to 50 Messages",
                            "👥 Create 5 Groups/Channels",
                          ],
                          isUltimate: false,
                        ),

                        const SizedBox(height: 25),

                        // 🟣 PLAN 2: ULTIMATE (₹599)
                        _buildPlanCard(
                          context,
                          title: "Ultimate Royal",
                          price: "₹599 / month",
                          numericPrice: 599,
                          color: const Color(0xFF6A11CB),
                          icon: Icons.workspace_premium,
                          features: [
                            "👻 Ghost Mode (Stealth)",
                            "👑 Animated Name & Crown Badge",
                            "📹 4K Original Quality Media",
                            "🚫 Ad-Free Experience",
                            "🔥 Unlimited Groups & Members",
                            "🚀 Priority Support",
                          ],
                          isUltimate: true, // Highlights this card
                        ),
                        
                        const SizedBox(height: 20),
                        const Center(child: Text("Secure Payment via Swift Wallet", style: TextStyle(color: Colors.grey, fontSize: 12))),
                      ],
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

  Widget _buildPlanCard(BuildContext context, {
    required String title, 
    required String price, 
    required int numericPrice,
    required Color color, 
    required IconData icon, 
    required List<String> features, 
    required bool isUltimate
  }) {
    return Stack(
      children: [
        // CARD CONTAINER
        Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: color.withOpacity(0.6), width: isUltimate ? 2 : 1),
            boxShadow: isUltimate 
              ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)] 
              : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ICON & TITLE
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 30),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(price, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 10),

              // FEATURES LIST
              ...features.map((feature) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: isUltimate ? Colors.greenAccent : Colors.white70, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(feature, style: const TextStyle(color: Colors.white70, fontSize: 14))),
                  ],
                ),
              )),

              const SizedBox(height: 25),

              // BUY BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to Wallet Screen for Payment with Plan Details
                    Navigator.push(context, MaterialPageRoute(builder: (_) => WalletScreen(
                      amount: numericPrice,
                      planName: title,
                    )));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isUltimate ? color : Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: isUltimate ? 10 : 0,
                    side: isUltimate ? BorderSide.none : const BorderSide(color: Colors.white24),
                  ),
                  child: Text(isUltimate ? "Get Ultimate Access" : "Choose Gold", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),

        // "RECOMMENDED" BADGE FOR ULTIMATE PLAN
        if (isUltimate)
          Positioned(
            top: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.only(topRight: Radius.circular(25), bottomLeft: Radius.circular(15)),
              ),
              child: const Text("MOST POPULAR", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }
}