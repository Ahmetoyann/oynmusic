import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider with ChangeNotifier {
  FirebaseAuth? _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _user;
  User? get user => _user;

  AuthProvider() {
    try {
      _auth = FirebaseAuth.instance;
      // Uygulama açıldığında mevcut oturumu dinle
      _auth?.authStateChanges().listen((User? user) {
        _user = user;
        notifyListeners();
      });
    } catch (e) {
      debugPrint("FirebaseAuth başlatılamadı: $e");
    }
  }

  /// Google ile Giriş Yap
  Future<User?> signInWithGoogle() async {
    // Eğer _auth başlatılamadıysa (örneğin main.dart'ta hata olduysa) tekrar dene
    if (_auth == null) {
      try {
        _auth = FirebaseAuth.instance;
      } catch (e) {
        debugPrint("FirebaseAuth başlatılamadı, giriş yapılamıyor: $e");
        return null;
      }
    }
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
      final UserCredential userCredential = await _auth!.signInWithCredential(
        credential,
      );

      return userCredential.user;
    } catch (e) {
      debugPrint("Google Giriş Hatası: $e");
      if (e is FirebaseAuthException) {
        debugPrint("Firebase Hata Kodu: ${e.code}");
        debugPrint("Firebase Hata Mesajı: ${e.message}");
      }
      rethrow;
    }
  }

  /// Çıkış Yap
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth?.signOut();
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
      _user = _auth?.currentUser;
      notifyListeners();
    } catch (e) {
      debugPrint("İsim güncelleme hatası: $e");
      rethrow;
    }
  }

  /// Kullanıcı verilerini Firebase üzerinden tazeler ve arayüzü günceller
  Future<void> reloadUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await currentUser.reload();
      // Değişkeninizi güncelleyin (Eğer içeride değişkeninizin adı _user ise _user olarak kullanın)
      _user = FirebaseAuth.instance.currentUser;
      notifyListeners(); // Trendler sayfası dahil her yeri tetikler
    }
  }
}
