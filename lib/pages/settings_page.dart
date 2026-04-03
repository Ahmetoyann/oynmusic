import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/providers/theme_provider.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/custom_app_bar.dart';
import 'package:muzik_app/custom_icons.dart';
import 'package:muzik_app/widgets/mini_player.dart';
import 'package:muzik_app/pages/player_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    const textColor = Colors.white;
    final subTextColor = Colors.grey.shade600;

    return Scaffold(
      extendBody: true,
      appBar: const CustomAppBar(title: 'Ayarlar', centerTitle: true),
      bottomNavigationBar: context.watch<SongProvider>().currentSong != null
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    const Color(0xFF121212),
                    const Color(0xFF121212).withOpacity(0.9),
                    const Color(0xFF121212).withOpacity(0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 0.8, 1.0],
                ),
              ),
              child: SafeArea(
                bottom: true,
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => PlayerPage.show(context),
                      child: const MiniPlayer(),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            )
          : null,
      body: Stack(
        children: [
          // Modern Arka Plan Parlaması
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).primaryColor.withOpacity(0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              context.watch<SongProvider>().currentSong != null ? 160 : 40,
            ),
            children: [
              // 1. Görünüm Ayarları
              _buildSectionHeader(context, 'Görünüm'),
              _buildSettingsCard(
                context,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildLeadingIcon(
                              Theme.of(context).primaryColor,
                              Icon(
                                Icons.color_lens_rounded,
                                color: Theme.of(context).primaryColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tema Rengi',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Uygulamanın ana vurgu rengini kişiselleştirin',
                                    style: TextStyle(
                                      color: subTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 60,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _buildColorOption(context, Colors.amber),
                              _buildColorOption(context, Colors.green),
                              _buildColorOption(context, Colors.teal),
                              _buildColorOption(context, Colors.cyan),
                              _buildColorOption(context, Colors.lightBlue),
                              _buildColorOption(context, Colors.blue),
                              _buildColorOption(context, Colors.indigo),
                              _buildColorOption(context, Colors.deepPurple),
                              _buildColorOption(context, Colors.purple),
                              _buildColorOption(context, Colors.pink),
                              _buildColorOption(context, Colors.red),
                              _buildColorOption(
                                context,
                                const Color(0xFF8B0000),
                              ),
                              _buildColorOption(context, Colors.deepOrange),
                              _buildColorOption(context, Colors.orange),
                              _buildColorOption(
                                context,
                                const Color.fromARGB(255, 101, 144, 32),
                              ),
                              _buildColorOption(context, Colors.yellow),
                              _buildColorOption(context, Colors.brown),
                              _buildColorOption(context, Colors.blueGrey),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 2. Müzik Ayarları
              _buildSectionHeader(context, 'Müzik'),
              _buildSettingsCard(
                context,
                children: [
                  ListTile(
                    leading: _buildLeadingIcon(
                      Colors.orange,
                      CustomIcons.svgIcon(
                        CustomIcons.timerRounded,
                        color: Colors.orange,
                        size: 24,
                      ),
                    ),
                    title: const Text(
                      'Uyku Zamanlayıcısı',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      context.watch<SongProvider>().isSleepTimerActive
                          ? 'Bitiş: ${_formatTime(context.watch<SongProvider>().sleepTimerEndTime!)}'
                          : 'Kapalı',
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.grey.shade600,
                      size: 14,
                    ),
                    onTap: () => _showSleepTimerDialog(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      height: 1,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  Consumer<SongProvider>(
                    builder: (context, provider, child) {
                      return SwitchListTile(
                        secondary: _buildLeadingIcon(
                          Colors.blueAccent,
                          const Icon(
                            Icons.data_usage_rounded,
                            color: Colors.blueAccent,
                            size: 24,
                          ),
                        ),
                        title: const Text(
                          'Veri Tasarrufu',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'Düşük kaliteli ses kullanarak tasarruf sağlar',
                          style: TextStyle(color: subTextColor, fontSize: 12),
                        ),
                        value: provider.isLowDataMode,
                        activeColor: Theme.of(context).primaryColor,
                        onChanged: (bool value) {
                          provider.toggleLowDataMode(value);
                        },
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      height: 1,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  ListTile(
                    leading: _buildLeadingIcon(
                      Colors.purpleAccent,
                      const Icon(
                        Icons.equalizer_rounded,
                        color: Colors.purpleAccent,
                        size: 24,
                      ),
                    ),
                    title: const Text(
                      'Ekolayzer',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'Ses frekanslarını kişiselleştirin',
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.grey.shade600,
                      size: 14,
                    ),
                    onTap: () => _showEqualizerBottomSheet(context),
                  ),
                ],
              ),

              // 3. Veri ve Depolama
              _buildSectionHeader(context, 'Veri ve Depolama'),
              _buildSettingsCard(
                context,
                children: [
                  ListTile(
                    leading: _buildLeadingIcon(
                      Colors.orange,
                      const Icon(
                        Icons.cleaning_services_rounded,
                        color: Colors.orange,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      'Arama Önbelleğini Temizle',
                      style: TextStyle(color: textColor),
                    ),
                    subtitle: Text(
                      'Arama ve Trendler sonuçlarını günceller.',
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.grey.shade600,
                      size: 14,
                    ),
                    onTap: () => _showClearApiCacheDialog(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(
                      height: 1,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  ListTile(
                    leading: _buildLeadingIcon(
                      Colors.red,
                      CustomIcons.svgIcon(
                        CustomIcons.delete,
                        color: Colors.red,
                      ),
                    ),
                    title: Text(
                      'Önbelleği Temizle',
                      style: TextStyle(color: textColor),
                    ),
                    subtitle: Text(
                      'İndirilen şarkıları ve favorileri siler.',
                      style: TextStyle(color: subTextColor, fontSize: 12),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.grey.shade600,
                      size: 14,
                    ),
                    onTap: () => _showClearCacheDialog(context),
                  ),
                ],
              ),

              // 4. Uygulama Hakkında
              _buildSectionHeader(context, 'Uygulama'),
              _buildSettingsCard(
                context,
                children: [
                  ListTile(
                    leading: _buildLeadingIcon(
                      Theme.of(context).primaryColor,
                      Image.asset(
                        'assets/icon/oyn_uyg_ikon.png',
                        width: 24,
                        height: 24,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    title: Text('Versiyon', style: TextStyle(color: textColor)),
                    trailing: FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) {
                        final version = snapshot.hasData
                            ? snapshot.data!.version
                            : '...';
                        return Text(
                          version,
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeadingIcon(Color color, Widget icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: icon,
    );
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildColorOption(BuildContext context, Color color) {
    final themeProvider = context.read<ThemeProvider>();
    final isSelected = themeProvider.primaryColor.value == color.value;

    return GestureDetector(
      onTap: () => themeProvider.setPrimaryColor(color),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: isSelected
            ? CustomIcons.svgIcon(
                CustomIcons.check,
                color: Colors.white,
                size: 20,
              )
            : null,
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) async {
    final provider = context.read<SongProvider>();
    final cacheSize = await provider.getCacheSize();

    if (!context.mounted) return;

    CustomBottomSheet.show(
      context: context,
      title: 'Emin misiniz?',
      message:
          'Tüm indirilen şarkılar ve favoriler silinecek ($cacheSize). Bu işlem geri alınamaz.',
      primaryButtonText: 'Temizle',
      primaryButtonColor: Colors.red,
      secondaryButtonText: 'İptal',
      onPrimaryButtonTap: () async {
        Navigator.pop(context);
        try {
          await context.read<SongProvider>().clearCache();
          if (context.mounted) {
            CustomSnackBar.showSuccess(
              context: context,
              message: 'Önbellek başarıyla temizlendi.',
            );
          }
        } catch (e) {
          if (context.mounted) {
            CustomSnackBar.showError(
              context: context,
              message: 'Bir hata oluştu.',
            );
          }
        }
      },
    );
  }

  void _showClearApiCacheDialog(BuildContext context) {
    CustomBottomSheet.show(
      context: context,
      title: 'API Önbelleğini Temizle',
      message:
          'Arama ve Trendler sonuçları yenilenecektir. İşleme devam edilsin mi?',
      primaryButtonText: 'Temizle',
      primaryButtonColor: Colors.orange,
      secondaryButtonText: 'İptal',
      onPrimaryButtonTap: () async {
        Navigator.pop(context);
        try {
          await context.read<SongProvider>().clearApiCache();
          if (context.mounted) {
            CustomSnackBar.showSuccess(
              context: context,
              message: 'API önbelleği başarıyla temizlendi.',
            );
          }
        } catch (e) {
          if (context.mounted) {
            CustomSnackBar.showError(
              context: context,
              message: 'Bir hata oluştu.',
            );
          }
        }
      },
    );
  }

  void _showSleepTimerDialog(BuildContext context) {
    CustomBottomSheet.showContent(
      context: context,
      child: Consumer<SongProvider>(
        builder: (context, provider, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomIcons.svgIcon(
                    CustomIcons.timerOutlined,
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Uyku Zamanlayıcısı',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (provider.isSleepTimerActive &&
                  provider.sleepTimerEndTime != null) ...[
                const SizedBox(height: 8),
                Text(
                  "Kapanış: ${provider.sleepTimerEndTime!.hour.toString().padLeft(2, '0')}:${provider.sleepTimerEndTime!.minute.toString().padLeft(2, '0')}",
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildModernTimerOption(context, 15),
                    _buildModernTimerOption(context, 30),
                    _buildModernTimerOption(context, 45),
                    _buildModernTimerOption(context, 60),
                    _buildModernTimerOption(context, 90),
                    _buildModernTimerOption(context, 120),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (provider.isSleepTimerActive)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        provider.cancelSleepTimer();
                        Navigator.pop(context);
                        CustomSnackBar.showInfo(
                          context: context,
                          message: 'Zamanlayıcı kapatıldı.',
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Zamanlayıcıyı Kapat",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModernTimerOption(BuildContext context, int minutes) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.read<SongProvider>().setSleepTimer(minutes);
          Navigator.pop(context);
          CustomSnackBar.showInfo(
            context: context,
            message: 'Müzik $minutes dakika sonra duracak.',
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: (MediaQuery.of(context).size.width - 64) / 3,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Text(
                "$minutes",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "dk",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEqualizerBottomSheet(BuildContext context) {
    CustomBottomSheet.showContent(
      context: context,
      isScrollControlled: true,
      child: const _EqualizerSheet(),
    );
  }
}

class _EqualizerSheet extends StatefulWidget {
  const _EqualizerSheet();

  @override
  State<_EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends State<_EqualizerSheet> {
  late bool _isEnabled;
  late List<double> _values;
  final List<String> _freqs = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];

  @override
  void initState() {
    super.initState();
    final provider = context.read<SongProvider>();
    _isEnabled = provider.isEqualizerEnabled;
    _values = List.from(provider.equalizerValues);
  }

  void _saveToProvider() {
    context.read<SongProvider>().updateEqualizerSettings(_isEnabled, _values);
  }

  void _reset() {
    setState(() {
      _values = [0.0, 0.0, 0.0, 0.0, 0.0];
    });
    _saveToProvider();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.equalizer_rounded,
                      color: primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Ekolayzer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _isEnabled,
                activeColor: primaryColor,
                onChanged: (val) {
                  setState(() => _isEnabled = val);
                  _saveToProvider();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isEnabled ? "Özel Ayar" : "Kapalı",
                style: TextStyle(
                  color: _isEnabled ? primaryColor : Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: _isEnabled ? _reset : null,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  "Sıfırla",
                  style: TextStyle(
                    color: _isEnabled ? Colors.white70 : Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                return Column(
                  children: [
                    Text(
                      _values[index] > 0
                          ? "+${_values[index].toInt()}dB"
                          : "${_values[index].toInt()}dB",
                      style: TextStyle(
                        color: _isEnabled ? Colors.white : Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: 3, // Dikey slider için çeviriyoruz
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 6,
                            activeTrackColor: _isEnabled
                                ? primaryColor
                                : Colors.grey.shade800,
                            inactiveTrackColor: _isEnabled
                                ? Colors.white.withOpacity(0.08)
                                : Colors.white.withOpacity(0.02),
                            thumbColor: _isEnabled
                                ? Colors.white
                                : Colors.grey.shade600,
                            overlayColor: primaryColor.withOpacity(0.2),
                            trackShape: const RoundedRectSliderTrackShape(),
                          ),
                          child: Slider(
                            value: _values[index],
                            min: -15,
                            max: 15,
                            divisions: 30, // Hassas geçişler
                            onChanged: _isEnabled
                                ? (val) {
                                    setState(() {
                                      _values[index] = val;
                                    });
                                  }
                                : null,
                            onChangeEnd: _isEnabled
                                ? (val) => _saveToProvider()
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _freqs[index],
                      style: TextStyle(
                        color: _isEnabled
                            ? Colors.grey.shade400
                            : Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
