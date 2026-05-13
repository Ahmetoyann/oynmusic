import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class InterstitialAdManager {
  // Reklam gösterimini geçici olarak kapatmak/açmak için bu değeri değiştirin (Geçici olarak: false)
  static const bool isAdsEnabled = false;

  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;

  // Geçiş (Interstitial) Reklam Birim Kimlikleri
  final String adUnitId = kIsWeb
      ? ''
      : (Platform.isAndroid
            ? 'ca-app-pub-7993140773979821/2439627976' // Sizin Android Geçiş Reklam Kimliğiniz
            : 'ca-app-pub-3940256099942544/4411468910'); // iOS Test ID

  void loadAd() {
    if (!isAdsEnabled || kIsWeb) return;
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd yüklenemedi: $error');
          _isAdLoaded = false;
        },
      ),
    );
  }

  void showAdIfAvailable() {
    if (!isAdsEnabled || kIsWeb) return;
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _isAdLoaded = false;
          loadAd(); // Kapatıldığında bir sonraki için yenisini yükle
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _isAdLoaded = false;
          loadAd();
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null; // Gösterildiği için referansı temizle
    } else {
      loadAd(); // Eğer hazır değilse yüklemeyi başlat
    }
  }
}
