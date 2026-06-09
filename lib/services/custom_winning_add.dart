import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';

class CustomWinningAd {
  // Singleton yapısı
  static final CustomWinningAd instance = CustomWinningAd._internal();
  factory CustomWinningAd() => instance;
  CustomWinningAd._internal();

  RewardedAd? _rewardedAd;
  bool _isLoaded = false;

  // Google AdMob Test Ödüllü Reklam Kimlikleri (Yayınlarken Kendi ID'nizle Değiştirin)
  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-7993140773979821/7182113331'
      : 'ca-app-pub-7993140773979821/7182113331';

  void loadAd() {
    RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoaded = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('Ödüllü Reklam yüklenemedi: $error');
          _isLoaded = false;
        },
      ),
    );
  }

  void showAd({
    required Function() onEarnedReward,
    required Function() onAdClosed,
  }) {
    if (!_isLoaded || _rewardedAd == null) {
      onAdClosed();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isLoaded = false;
        loadAd(); // Bir sonraki kullanım için reklamı tekrar yükle
        onAdClosed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isLoaded = false;
        loadAd();
        onAdClosed();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        onEarnedReward();
      },
    );
  }

  // Modern Jeton Bakiyesi ve Reklam İzleme Tam Ekranı
  static void showCoinScreen(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    bool isLoadingAd = false;

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Theme.of(pageContext).scaffoldBackgroundColor,
            body: SafeArea(
              child: StatefulBuilder(
                builder: (context, setState) {
                  final provider = context.watch<SongProvider>();
                  final langProvider = context.watch<LanguageProvider>();
                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 32),
                            onPressed: () => Navigator.pop(pageContext),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.monetization_on_rounded,
                          size: 100, color: Colors.amber),
                      const SizedBox(height: 24),
                      Text(
                        langProvider.t('coin_balance'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "${provider.coins} ${langProvider.t('coins')}",
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Text(
                          langProvider.t('coin_info_text'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextButton.icon(
                        onPressed: () =>
                            _showCoinHistoryScreen(pageContext, provider),
                        icon: const Icon(Icons.history_rounded,
                            color: Colors.white70),
                        label: Text(
                          langProvider.t('coin_history'),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: InkWell(
                                onTap: isLoadingAd
                                    ? null
                                    : () {
                                        if (!CustomWinningAd
                                            .instance._isLoaded) {
                                          CustomSnackBar.showError(
                                              context: pageContext,
                                              message: langProvider
                                                  .t('ad_preparing'));
                                          CustomWinningAd.instance.loadAd();
                                          return;
                                        }
                                        setState(() => isLoadingAd = true);
                                        CustomWinningAd.instance.showAd(
                                          onEarnedReward: () {
                                            provider.addCoins(4,
                                                reason:
                                                    "Reklam İzleme"); // +4 Jeton Ekle
                                            CustomSnackBar.showSuccess(
                                                context: pageContext,
                                                message: langProvider
                                                    .t('earned_4_coins'));
                                          },
                                          onAdClosed: () {
                                            setState(() => isLoadingAd = false);
                                          },
                                        );
                                      },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.amber.withOpacity(0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: isLoadingAd
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                                color: Colors.amber,
                                                strokeWidth: 2.5),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                  Icons
                                                      .play_circle_outline_rounded,
                                                  color: Colors.amber,
                                                  size: 24),
                                              SizedBox(width: 8),
                                              Text(
                                                langProvider.t('watch_ad_btn'),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.amber,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
              position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  static void _showCoinHistoryScreen(
      BuildContext context, SongProvider provider) {
    final langProvider = context.read<LanguageProvider>();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (pageContext, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Theme.of(pageContext).scaffoldBackgroundColor,
            body: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 32),
                        onPressed: () => Navigator.pop(pageContext),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(Icons.history_rounded,
                      size: 64, color: Theme.of(context).primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    langProvider.t('coin_history'),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: provider.coinHistory.isEmpty
                        ? Center(
                            child: Text(
                              langProvider.t('no_transactions'),
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 16),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            physics: const BouncingScrollPhysics(),
                            itemCount: provider.coinHistory.length,
                            separatorBuilder: (context, index) =>
                                Divider(color: Colors.white.withOpacity(0.05)),
                            itemBuilder: (context, index) {
                              final transaction = provider.coinHistory[index];
                              final isEarned = transaction['isEarned'] as bool;
                              final amount = transaction['amount'] as int;
                              final desc = transaction['description'] as String;
                              final dateStr = transaction['date'] as String;
                              final date = DateTime.parse(dateStr);
                              final formattedDate =
                                  "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isEarned
                                        ? Colors.greenAccent.withOpacity(0.2)
                                        : Colors.redAccent.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isEarned
                                        ? Icons.add_rounded
                                        : Icons.remove_rounded,
                                    color: isEarned
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  desc,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                subtitle: Text(
                                  formattedDate,
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12),
                                ),
                                trailing: Text(
                                  "${isEarned ? '+' : '-'}$amount",
                                  style: TextStyle(
                                    color: isEarned
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin =
              Offset(1.0, 0.0); // Ekranın sağından içeri kayarak gelir
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
              position: animation.drive(tween), child: child);
        },
      ),
    );
  }
}
