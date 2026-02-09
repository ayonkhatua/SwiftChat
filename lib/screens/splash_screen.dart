import 'dart:async';
import 'dart:ui'; // Glass effect
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Animation Setup (2 seconds duration)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Fade In Effect
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // Scale Up Effect (Bounce ke saath)
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward(); // Animation shuru karo

    // 2. Navigation Timer (3 seconds baad check karo)
    Timer(const Duration(seconds: 3), () {
      if (!mounted) return; // 🟢 Fix: Agar screen hat gayi hai to crash mat karo
      // Check karo user pehle se logged in hai ya nahi
      if (FirebaseAuth.instance.currentUser != null) {
        Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen())
        );
      } else {
        Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const LoginScreen())
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 🟢 BACKGROUND GLOW (Wahi Premium Glass Theme)
          Positioned(
            top: -100, left: -50,
            child: Container(
              height: 300, width: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF6A11CB).withOpacity(0.4),
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Color(0xFF6A11CB), blurRadius: 120, spreadRadius: 40)],
              ),
            ),
          ),
          Positioned(
            bottom: -50, right: -50,
            child: Container(
              height: 300, width: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF2575FC).withOpacity(0.4),
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Color(0xFF2575FC), blurRadius: 120, spreadRadius: 40)],
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),

          // 🟢 ANIMATED LOGO & TEXT
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Custom Logo Stack (Bubble + Bolt)
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Glow Ring
                        Container(
                          height: 100, width: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF6A11CB).withOpacity(0.5), blurRadius: 30, spreadRadius: 5),
                              BoxShadow(color: const Color(0xFF2575FC).withOpacity(0.5), blurRadius: 30, spreadRadius: 5),
                            ]
                          ),
                        ),
                        // Main Icons
                        const Icon(Icons.chat_bubble_rounded, size: 90, color: Colors.white),
                        const Positioned(
                          top: 22,
                          child: Icon(Icons.bolt_rounded, size: 50, color: Color(0xFF2575FC)), // Blue Bolt inside
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 25),
                    
                    // App Name
                    const Text(
                      "SwiftChat",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(color: Color(0xFF6A11CB), blurRadius: 15, offset: Offset(0, 5))
                        ]
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Fast. Secure. Premium.",
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, letterSpacing: 1),
                    ),

                    const SizedBox(height: 60),
                    // Loading Indicator
                    const CircularProgressIndicator(color: Color(0xFF6A11CB)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}