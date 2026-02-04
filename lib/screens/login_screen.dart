import 'dart:ui'; // Glass Effect ke liye
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _nameController = TextEditingController(); 

  bool isLogin = true; 
  bool isLoading = false;

  void submit() async {
    String email = _emailController.text.trim();
    String password = _passController.text.trim();
    String username = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog("Please enter both email and password.");
      return;
    }

    if (!isLogin && username.isEmpty) {
      _showErrorDialog("Please enter a username.");
      return;
    }

    setState(() => isLoading = true);
    try {
      if (isLogin) {
        await _auth.signIn(email, password);
      } else {
        await _auth.signUp(email, password, username);
      }
      
      if (!mounted) return;
      // Login Success
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));

    } catch (e) {
      String errorMessage = "An error occurred. Please try again.";

      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'user-not-found':
            errorMessage = "No account found with this email.";
            break;
          case 'wrong-password':
            errorMessage = "Incorrect Password.";
            break;
          case 'invalid-credential':
            errorMessage = "Invalid Email or Password.";
            break;
          case 'email-already-in-use':
            errorMessage = "Email is already registered. Please login.";
            break;
          case 'invalid-email':
            errorMessage = "Please enter a valid email address.";
            break;
          case 'weak-password':
            errorMessage = "Password should be at least 6 characters.";
            break;
          default:
            errorMessage = e.message ?? "Authentication failed.";
        }
      }

      if (mounted) _showErrorDialog(errorMessage);
    }
    if (mounted) setState(() => isLoading = false);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Row(children: [Icon(Icons.error_outline, color: Colors.redAccent), SizedBox(width: 10), Text("Oops!", style: TextStyle(color: Colors.white))]),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK", style: TextStyle(color: Colors.blueAccent)))],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 🟢 1. BACKGROUND GLOW (Ambient Light)
          Positioned(
            top: -100, left: -50,
            child: Container(
              height: 300, width: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF6A11CB).withOpacity(0.5), // Purple
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Color(0xFF6A11CB), blurRadius: 120, spreadRadius: 60)],
              ),
            ),
          ),
          Positioned(
            bottom: -50, right: -50,
            child: Container(
              height: 300, width: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF2575FC).withOpacity(0.5), // Blue
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Color(0xFF2575FC), blurRadius: 120, spreadRadius: 60)],
              ),
            ),
          ),

          // 🟢 2. BLUR FILTER (Frosted Glass Effect)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.black.withOpacity(0.3)), // Thoda dark tint
          ),

          // 🟢 3. MAIN FORM (Floating Glass Card)
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Icon with Glow
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF6A11CB).withOpacity(0.3), blurRadius: 20, spreadRadius: 5)
                      ]
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, size: 60, color: Colors.white),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Animated Title
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: Text(
                      isLogin ? "Welcome Back" : "Join SwiftChat",
                      key: ValueKey(isLogin),
                      style: const TextStyle(
                        color: Colors.white, 
                        fontSize: 32, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isLogin ? "Sign in to continue" : "Create a new account",
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),

                  const SizedBox(height: 40),

                  // 🟢 GLASS CARD CONTAINER
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        if (!isLogin) ...[
                          _buildPremiumTextField(_nameController, "Username", Icons.person_outline),
                          const SizedBox(height: 15),
                        ],

                        _buildPremiumTextField(_emailController, "Email Address", Icons.alternate_email),
                        const SizedBox(height: 15),
                        _buildPremiumTextField(_passController, "Password", Icons.lock_outline, isPass: true),

                        const SizedBox(height: 25),

                        // 🟢 GRADIENT BUTTON
                        isLoading 
                        ? const CircularProgressIndicator(color: Color(0xFF6A11CB))
                        : Container(
                            width: double.infinity,
                            height: 55,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6A11CB).withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                )
                              ]
                            ),
                            child: ElevatedButton(
                              onPressed: submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                              child: Text(
                                isLogin ? "LOGIN" : "CREATE ACCOUNT", 
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  
                  // Toggle Button
                  TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: RichText(
                      text: TextSpan(
                        text: isLogin ? "Don't have an account? " : "Already have an account? ",
                        style: const TextStyle(color: Colors.grey),
                        children: [
                          TextSpan(
                            text: isLogin ? "Sign Up" : "Log In",
                            style: const TextStyle(color: Color(0xFF2575FC), fontWeight: FontWeight.bold),
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget for TextFields
  Widget _buildPremiumTextField(TextEditingController controller, String hint, IconData icon, {bool isPass = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3), // Darker background inside glass
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPass,
        style: const TextStyle(color: Colors.white),
        cursorColor: const Color(0xFF2575FC),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white60, size: 20),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}