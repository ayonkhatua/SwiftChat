import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart'; // Ab ye file exist karti hai, to error nahi aayega

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _nameController = TextEditingController(); // Sirf register ke liye

  bool isLogin = true; // Toggle between Login & Register
  bool isLoading = false;

  void submit() async {
    setState(() => isLoading = true);
    try {
      if (isLogin) {
        // Login Logic
        await _auth.signIn(
          _emailController.text.trim(), 
          _passController.text.trim()
        );
      } else {
        // Register Logic
        await _auth.signUp(
          _emailController.text.trim(), 
          _passController.text.trim(),
          _nameController.text.trim()
        );
      }
      
      // ✅ CHANGE: Ab ye line active hai. Login hote hi Home Screen khulegi.
      print("Login Successful!");
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error: ${e.toString()}"),
        backgroundColor: Colors.red,
      ));
    }
    // Agar widget abhi bhi screen par hai tabhi state update karo
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.purpleAccent),
              const SizedBox(height: 20),
              Text(
                isLogin ? "Welcome Back" : "Create Account",
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),

              if (!isLogin) ...[
                _buildTextField(_nameController, "Username", Icons.person),
                const SizedBox(height: 16),
              ],

              _buildTextField(_emailController, "Email", Icons.email),
              const SizedBox(height: 16),
              _buildTextField(_passController, "Password", Icons.lock, isPass: true),
              
              const SizedBox(height: 30),

              isLoading 
              ? const CircularProgressIndicator(color: Colors.purpleAccent)
              : SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isLogin ? "LOGIN" : "REGISTER", style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),

              const SizedBox(height: 20),
              TextButton(
                onPressed: () => setState(() => isLogin = !isLogin),
                child: Text(
                  isLogin ? "New user? Create Account" : "Already have account? Login",
                  style: const TextStyle(color: Colors.grey),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isPass = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPass,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.purpleAccent),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}