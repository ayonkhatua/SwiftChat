import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Current User kaun hai?
  User? get currentUser => _auth.currentUser;

  // 1. Sign Up (Register)
  Future<UserCredential> signUp(String email, String password, String username) async {
    try {
      // Firebase Auth mein user banao
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );

      // Firestore mein user ki details save karo
      await _db.collection('users').doc(result.user!.uid).set({
        'uid': result.user!.uid,
        'email': email,
        'username': username,
        'createdAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      return result;
    } catch (e) {
      rethrow;
    }
  }

  // 2. Sign In (Login)
  Future<UserCredential> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      // Login hote hi Online status update karo
      await _db.collection('users').doc(result.user!.uid).update({
        'isOnline': true,
      });
      
      return result;
    } catch (e) {
      rethrow;
    }
  }

  // 3. Sign Out
  Future<void> signOut() async {
    if (_auth.currentUser != null) {
      await _db.collection('users').doc(_auth.currentUser!.uid).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      await _auth.signOut();
    }
  }
}