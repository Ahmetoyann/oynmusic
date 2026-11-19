import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:flutter/foundation.dart';
import 'package:muzik_app/utils/responsive.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  int _passwordStrength = 0; // Şifre güç seviyesini tutan değişken

  @override
  void initState() {
    super.initState();
    // Şifre kutucuğundaki her değişimi dinle
    _passwordController.addListener(_checkPasswordStrength);
  }

  void _checkPasswordStrength() {
    final password = _passwordController.text;
    int strength = 0;

    if (password.isNotEmpty) {
      bool hasLetters = RegExp(r'[a-zA-Z]').hasMatch(password);
      bool hasNumbers = RegExp(r'\d').hasMatch(password);
      bool hasSpecials = RegExp(r'[!@#\$&*~_\-.,+=\\\/|?]').hasMatch(password);

      if (password.length >= 8 && hasLetters && hasNumbers && hasSpecials) {
        strength = 3; // Güçlü (8+ karakter, harf, rakam ve özel karakter)
      } else if (password.length >= 6 && hasLetters && hasNumbers) {
        strength = 2; // Orta (6+ karakter, harf ve rakam)
      } else {
        strength = 1; // Zayıf (Yukarıdaki şartları sağlamıyor)
      }
    }

    if (_passwordStrength != strength) {
      setState(() => _passwordStrength = strength);
    }
  }

  Future<void> _nextPage() async {
    final langProvider = context.read<LanguageProvider>();
    // Doğrulamalar
    if (_currentPage == 0) {
      if (_firstNameController.text.trim().isEmpty ||
          _lastNameController.text.trim().isEmpty) {
        CustomSnackBar.showError(
            context: context,
            message: langProvider.t('enter_first_last_name_warning'));
        return;
      }
    } else if (_currentPage == 1) {
      if (_dobController.text.trim().isEmpty) {
        CustomSnackBar.showError(
            context: context, message: langProvider.t('enter_dob_warning'));
        return;
      }
    } else if (_currentPage == 2) {
      final email = _emailController.text.trim();
      final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (email.isEmpty || !emailRegExp.hasMatch(email)) {
        CustomSnackBar.showError(
            context: context, message: langProvider.t('enter_valid_email'));
        return;
      }
    } else if (_currentPage == 3) {
      if (_passwordStrength < 2) {
        CustomSnackBar.showError(
            context: context,
            message: langProvider.t('password_rules_warning'));
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        CustomSnackBar.showError(
            context: context, message: langProvider.t('passwords_not_match'));
        return;
      }

      // Firebase Kayıt İşlemi
      setState(() => _isLoading = true);
      try {
        final authProvider = context.read<AuthProvider>();
        final displayName =
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
        final user = await authProvider.registerWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          displayName,
        );
        if (user != null && mounted) {
          // Kayıt başarılı, anasayfaya (AuthWrapper tarafından yakalanır) veya ilk ekrana geri dön
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          CustomSnackBar.showError(
            context: context,
            message: e.toString().replaceAll('Exception: ', ''),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_checkPasswordStrength);
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final langProvider = context.watch<LanguageProvider>();
    final isTablet = Responsive.isTabletOrLandscape(context);

    if (isTablet) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: SafeArea(
          child: _buildTabletLayout(context, primaryColor, langProvider),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _prevPage,
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color:
                    _currentPage == index ? primaryColor : Colors.grey.shade700,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics:
              const NeverScrollableScrollPhysics(), // Kaydırma butonlara bırakıldı
          onPageChanged: (idx) => setState(() => _currentPage = idx),
          children: [
            _buildPage1(primaryColor, langProvider),
            _buildPage2(primaryColor, langProvider),
            _buildPage3(primaryColor, langProvider),
            _buildPage4(primaryColor, langProvider),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(30.0),
        child: _buildNextButton(primaryColor, langProvider),
      ),
    );
  }

  Widget _buildNextButton(Color primaryColor, LanguageProvider langProvider) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryColor.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: (_isLoading ||
                        (_currentPage == 3 && _passwordStrength == 1))
                    ? null
                    : _nextPage,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _currentPage == 3
                                ? langProvider.t('register')
                                : langProvider.t('next'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalStepIndicator(
      Color primaryColor, LanguageProvider langProvider) {
    final steps = [
      {'title': langProvider.t('first_name'), 'icon': Icons.person_outline},
      {'title': langProvider.t('your_dob'), 'icon': Icons.calendar_today_outlined},
      {'title': langProvider.t('your_email'), 'icon': Icons.email_outlined},
      {'title': langProvider.t('password'), 'icon': Icons.lock_outline},
    ];

    return Column(
      children: List.generate(steps.length, (index) {
        final isCompleted = _currentPage > index;
        final isActive = _currentPage == index;
        final step = steps[index];

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? primaryColor
                      : (isActive
                          ? primaryColor.withOpacity(0.2)
                          : Colors.white.withOpacity(0.05)),
                  border: Border.all(
                    color: (isActive || isCompleted)
                        ? primaryColor
                        : Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isActive ? primaryColor : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  step['title'] as String,
                  style: TextStyle(
                    color: isActive
                        ? Colors.white
                        : (isCompleted
                            ? Colors.grey.shade300
                            : Colors.grey.shade600),
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTabletLayout(BuildContext context, Color primaryColor,
      LanguageProvider langProvider) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sol Bölüm: Adım Göstergesi ve Başlık
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back,
                                  color: Colors.white),
                              onPressed: _prevPage,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Image.asset(
                                  'assets/icon/OYN_ana_logo_seffaf.png',
                                  height: 36,
                                  width: 36,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "OYN Music",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              langProvider.t('register'),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 28),
                            _buildVerticalStepIndicator(
                                primaryColor, langProvider),
                          ],
                        ),
                      ),
                      Container(
                        height: 380,
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        color: Colors.white.withOpacity(0.08),
                      ),
                      // Sağ Bölüm: Form Sayfaları ve Buton
                      Expanded(
                        flex: 6,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 320,
                              child: PageView(
                                controller: _pageController,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                onPageChanged: (idx) =>
                                    setState(() => _currentPage = idx),
                                children: [
                                  _buildPage1(primaryColor, langProvider,
                                      isTablet: true),
                                  _buildPage2(primaryColor, langProvider,
                                      isTablet: true),
                                  _buildPage3(primaryColor, langProvider,
                                      isTablet: true),
                                  _buildPage4(primaryColor, langProvider,
                                      isTablet: true),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildNextButton(primaryColor, langProvider),
                          ],
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
    );
  }

  Widget _buildPage1(Color primaryColor, LanguageProvider langProvider,
      {bool isTablet = false}) {
    return Padding(
      padding: EdgeInsets.all(isTablet ? 8.0 : 30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(langProvider.t('can_we_know_you'),
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: primaryColor)),
          const SizedBox(height: 8),
          Text(langProvider.t('enter_first_last_name'),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
          SizedBox(height: isTablet ? 24 : 48),
          _buildTextField(_firstNameController, langProvider.t('first_name'),
              Icons.person_outline),
          const SizedBox(height: 16),
          _buildTextField(
              _lastNameController, langProvider.t('last_name'), Icons.person),
        ],
      ),
    );
  }

  Widget _buildPage2(Color primaryColor, LanguageProvider langProvider,
      {bool isTablet = false}) {
    return Padding(
      padding: EdgeInsets.all(isTablet ? 8.0 : 30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(langProvider.t('your_dob'),
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: primaryColor)),
          const SizedBox(height: 8),
          Text(langProvider.t('dob_desc'),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
          SizedBox(height: isTablet ? 24 : 48),
          GestureDetector(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime(2000, 1, 1),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.dark(
                        primary: primaryColor,
                        onPrimary: primaryColor.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                        surface: Colors.grey.shade900,
                        onSurface: Colors.white,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (date != null) {
                _dobController.text =
                    "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
              }
            },
            child: AbsorbPointer(
              child: _buildTextField(_dobController,
                  langProvider.t('dd_mm_yyyy'), Icons.calendar_today),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage3(Color primaryColor, LanguageProvider langProvider,
      {bool isTablet = false}) {
    return Padding(
      padding: EdgeInsets.all(isTablet ? 8.0 : 30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(langProvider.t('your_email'),
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: primaryColor)),
          const SizedBox(height: 8),
          Text(langProvider.t('email_desc'),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
          SizedBox(height: isTablet ? 24 : 48),
          _buildTextField(_emailController, langProvider.t('example_email'),
              Icons.email_outlined,
              keyboardType: TextInputType.emailAddress),
        ],
      ),
    );
  }

  Widget _buildPage4(Color primaryColor, LanguageProvider langProvider,
      {bool isTablet = false}) {
    return Padding(
      padding: EdgeInsets.all(isTablet ? 8.0 : 30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(langProvider.t('choose_secure_password'),
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: primaryColor)),
          const SizedBox(height: 8),
          Text(langProvider.t('password_desc'),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
          SizedBox(height: isTablet ? 16 : 48),
          _buildTextField(_passwordController, langProvider.t('password'),
              Icons.lock_outline,
              isPassword: true),
          const SizedBox(height: 12),
          _buildPasswordStrengthIndicator(langProvider),
          const SizedBox(height: 16),
          _buildTextField(_confirmPasswordController,
              langProvider.t('confirm_password'), Icons.lock_outline,
              isPassword: true),
        ],
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator(LanguageProvider langProvider) {
    String label = "";
    Color color = Colors.grey.shade500;

    if (_passwordStrength == 1) {
      label = langProvider.t('weak_password');
      color = Colors.redAccent;
    } else if (_passwordStrength == 2) {
      label = langProvider.t('medium_password');
      color = Colors.orangeAccent;
    } else if (_passwordStrength == 3) {
      label = langProvider.t('strong_password');
      color = Colors.greenAccent;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildStrengthBar(1)),
            const SizedBox(width: 8),
            Expanded(child: _buildStrengthBar(2)),
            const SizedBox(width: 8),
            Expanded(child: _buildStrengthBar(3)),
          ],
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ]
      ],
    );
  }

  Widget _buildStrengthBar(int level) {
    Color color = Colors.grey.shade800;
    if (_passwordStrength >= level) {
      if (_passwordStrength == 1) {
        color = Colors.redAccent;
      } else if (_passwordStrength == 2) {
        color = Colors.orangeAccent;
      } else if (_passwordStrength == 3) {
        color = Colors.greenAccent;
      }
    }
    return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 4,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(2)));
  }

  Widget _buildTextField(
      TextEditingController controller, String hint, IconData icon,
      {bool isPassword = false, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        prefixIcon: Icon(icon, color: Colors.grey.shade400),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey.shade400),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword))
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
      ),
    );
  }
}
