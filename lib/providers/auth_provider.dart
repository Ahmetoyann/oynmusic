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

  /// Firebase hata kodlarını Türkçeleştirir
  String _translateAuthError(String code, String? defaultMessage) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Girdiğiniz e-posta adresi veya şifre hatalı.';
      case 'invalid-email':
        return 'Geçersiz bir e-posta adresi girdiniz.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi ile zaten bir hesap oluşturulmuş.';
      case 'operation-not-allowed':
        return 'E-posta/Şifre ile giriş işlemi yapılandırması kapalı.';
      case 'weak-password':
        return 'Daha güçlü bir şifre belirlemelisiniz (En az 6 karakter).';
      case 'network-request-failed':
        return 'İnternet bağlantısı kurulamadı. Lütfen ağınızı kontrol edin.';
      case 'too-many-requests':
        return 'Çok fazla başarısız deneme yaptınız. Lütfen bir süre sonra tekrar deneyin.';
      default:
        return defaultMessage ?? 'Bilinmeyen bir hata oluştu.';
    }
  }

  /// E-posta ve Şifre ile Kayıt Ol
  Future<User?> registerWithEmailPassword(
      String email, String password, String displayName) async {
    if (_auth == null) {
      try {
        _auth = FirebaseAuth.instance;
      } catch (e) {
        debugPrint("FirebaseAuth başlatılamadı: $e");
        return null;
      }
    }
    try {
      final UserCredential userCredential =
          await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(displayName);
        await userCredential.user!.reload();
        _user = _auth!.currentUser;
        notifyListeners();
      }
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Kayıt Hatası: ${e.code}");
      throw Exception(_translateAuthError(e.code, e.message));
    } catch (e) {
      debugPrint("Kayıt Hatası: $e");
      throw Exception("Kayıt işlemi başarısız oldu.");
    }
  }

  /// E-posta ve Şifre ile Giriş Yap
  Future<User?> signInWithEmailPassword(String email, String password) async {
    if (_auth == null) {
      try {
        _auth = FirebaseAuth.instance;
      } catch (e) {
        debugPrint("FirebaseAuth başlatılamadı: $e");
        return null;
      }
    }
    try {
      final UserCredential userCredential =
          await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = userCredential.user;
      notifyListeners();
      return _user;
    } on FirebaseAuthException catch (e) {
      debugPrint("Giriş Hatası: ${e.code}");
      throw Exception(_translateAuthError(e.code, e.message));
    } catch (e) {
      debugPrint("Giriş Hatası: $e");
      throw Exception("Giriş işlemi başarısız oldu.");
    }
  }

  /// Şifre Sıfırlama E-postası Gönder
  Future<void> resetPassword(String email) async {
    if (_auth == null) {
      try {
        _auth = FirebaseAuth.instance;
      } catch (e) {
        debugPrint("FirebaseAuth başlatılamadı: $e");
        throw Exception("Kimlik doğrulama servisi başlatılamadı.");
      }
    }
    try {
      await _auth!.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      debugPrint("Şifre Sıfırlama Hatası: ${e.code}");
      throw Exception(_translateAuthError(e.code, e.message));
    } catch (e) {
      debugPrint("Şifre Sıfırlama Hatası: $e");
      throw Exception("Şifre sıfırlama e-postası gönderilemedi.");
    }
  }

  /// E-posta Doğrulama Bağlantısı Gönder
  Future<void> sendEmailVerification() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && !currentUser.emailVerified) {
        await currentUser.sendEmailVerification();
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Doğrulama E-postası Hatası: ${e.code}");
      throw Exception(_translateAuthError(e.code, e.message));
    } catch (e) {
      debugPrint("Doğrulama E-postası Hatası: $e");
      throw Exception("Doğrulama e-postası gönderilemedi.");
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
