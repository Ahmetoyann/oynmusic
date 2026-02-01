import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _user;
  User? get user => _user;

  AuthProvider() {
    // Uygulama açıldığında mevcut oturumu dinle
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  /// Google ile Giriş Yap
  Future<User?> signInWithGoogle() async {
    try {
      // 1. Google Sign In akışını başlat
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // Kullanıcı iptal etti

      // 2. Kimlik doğrulama detaylarını al
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Firebase için yeni bir kimlik bilgisi oluştur
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Firebase'e giriş yap
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      return userCredential.user;
    } catch (e) {
      debugPrint("Google Giriş Hatası: $e");
      rethrow;
    }
  }

  /// Çıkış Yap
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint("Çıkış Hatası: $e");
    }
  }

  /// Kullanıcı ismini güncelle
  Future<void> updateDisplayName(String name) async {
    if (_user == null) return;
    try {
      await _user!.updateDisplayName(name);
      await _user!.reload();
      _user = _auth.currentUser;
      notifyListeners();
    } catch (e) {
      debugPrint("İsim güncelleme hatası: $e");
      rethrow;
    }
  }
}
