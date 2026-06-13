import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService with ChangeNotifier {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  firebase_auth.User? _currentUser;
  // ignore: unused_field
  String? _verificationId;
  String? _phoneNumber;

  firebase_auth.User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  String? get currentPhoneNumber => _phoneNumber;

  // Initialize and check if user is already logged in
  Future<void> initializeAuth() async {
    try {
      _currentUser = _auth.currentUser;
      if (_currentUser != null) {
        _phoneNumber = _currentUser!.phoneNumber;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing auth: $e');
    }
  }

  // Verify phone number and send OTP
  Future<void> verifyPhoneNumber(
    String phoneNumber,
    Function(String verificationId, int? resendToken) onCodeSent,
    Function(String errorMessage) onError,
  ) async {
    try {
      _phoneNumber = phoneNumber;
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted:
            (firebase_auth.PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (firebase_auth.FirebaseAuthException e) {
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  // Sign in with OTP
  Future<Map<String, dynamic>> signInWithOTP(
      String verificationId, String smsCode) async {
    try {
      final credential = firebase_auth.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final result = await _auth.signInWithCredential(credential);
      final firebaseUser = result.user;
      if (firebaseUser == null) {
        return {'success': false, 'error': 'Sign-in failed'};
      }

      _currentUser = firebaseUser;
      _phoneNumber = firebaseUser.phoneNumber;
      notifyListeners();
      return {'success': true, 'isNewUser': false};
    } catch (e) {
      debugPrint('Error signing in with OTP: $e');
      return {'success': false, 'error': e.toString()};
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
      _phoneNumber = firebaseUser.phoneNumber;
      notifyListeners();
      return {'success': true, 'isNewUser': false};
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
    _currentUser = null;
    _phoneNumber = null;
    _verificationId = null;
    notifyListeners();
  }
}
