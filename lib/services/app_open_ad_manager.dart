import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AppOpenAdManager {
  // Reklam gösterimini geçici olarak kapatmak/açmak için bu değeri değiştirin (Geçici olarak: false)
  static const bool isAdsEnabled = false;

  // Uygulamanın ana akışına (MainScreen) geçilip geçilmediğini tutar
  static bool isMainScreenVisible = false;

  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;
  DateTime? _appOpenLoadTime;

  // Uygulama Açıkken (App Open) Reklam Birim Kimlikleri
  final String adUnitId = kIsWeb
      ? ''
      : (Platform.isAndroid
          ? 'ca-app-pub-7993140773979821/1724862393' // Sizin Android Kimliğiniz
          : 'ca-app-pub-3940256099942544/5662855259'); // iOS test kimliği

  void loadAd() {
    if (!isAdsEnabled || kIsWeb) return;
    AppOpenAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenLoadTime = DateTime.now();
          _appOpenAd = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('AppOpenAd yüklenemedi: $error');
        },
      ),
    );
  }

  bool get isAdAvailable {
    return _appOpenAd != null;
  }

  void showAdIfAvailable() {
    if (!isAdsEnabled || kIsWeb) return;
    if (!isAdAvailable) {
      loadAd();
      return;
    }
    if (_isShowingAd) {
      return;
    }
    // Google AdMob kurallarına göre App Open Ad'ler 4 saat geçerlidir
    if (_appOpenLoadTime != null &&
        DateTime.now()
            .subtract(const Duration(hours: 4))
            .isAfter(_appOpenLoadTime!)) {
      _appOpenAd!.dispose();
      _appOpenAd = null;
      loadAd();
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => _isShowingAd = true,
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAd(); // Kapatıldığında bir sonraki sefer için yenisini yükle
      },
    );
    _appOpenAd!.show();
  }
}
