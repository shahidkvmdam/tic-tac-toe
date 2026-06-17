import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'avatar_service.dart';

class AuthService with ChangeNotifier {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  firebase_auth.User? _currentUser;

  firebase_auth.User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get hasUsername =>
      _currentUser?.displayName != null &&
      _currentUser!.displayName!.trim().isNotEmpty;

  // Initialize and check if user is already logged in
  Future<void> initializeAuth() async {
    try {
      _currentUser = _auth.currentUser;
      if (_currentUser != null) {
        await AvatarService.instance.loadForUser(_currentUser!.uid);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing auth: $e');
    }
  }

  // Sign in with Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return {'success': false, 'error': 'Google sign-in cancelled'};
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final firebaseUser = result.user;
      if (firebaseUser == null) {
        return {'success': false, 'error': 'Sign-in failed'};
      }

      _currentUser = firebaseUser;
      await AvatarService.instance.loadForUser(firebaseUser.uid);
      notifyListeners();
      return {'success': true, 'isNewUser': false};
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Update display name
  Future<Map<String, dynamic>> updateDisplayName(String name) async {
    try {
      final trimmedName = name.trim();
      await _auth.currentUser?.updateDisplayName(trimmedName);
      await _auth.currentUser?.reload();
      _currentUser = _auth.currentUser;
      
      // Also save to Firestore users collection for search
      if (_currentUser != null) {
        await _db.collection('users').doc(_currentUser!.uid).set({
          'displayName': trimmedName,
          'uid': _currentUser!.uid,
        }, SetOptions(merge: true));
      }
      
      notifyListeners();
      return {'success': true};
    } catch (e) {
      debugPrint('Error updating display name: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Logout
  Future<void> logout() async {
    await AvatarService.instance.clearCurrentUser();
    await _auth.signOut();
    await _googleSignIn.signOut();
    _currentUser = null;
    notifyListeners();
  }
}
