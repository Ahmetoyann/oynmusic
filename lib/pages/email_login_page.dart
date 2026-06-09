import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:muzik_app/pages/register_page.dart';
import 'package:provider/provider.dart';
import 'package:muzik_app/providers/auth_provider.dart';
import 'package:muzik_app/providers/song_provider.dart';
import 'package:muzik_app/providers/language_provider.dart';
import 'package:muzik_app/widgets/custom_snack_bar.dart';
import 'package:muzik_app/widgets/custom_bottom_sheet.dart';

class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({super.key});

  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  bool _rememberMe = true;
  bool _obscurePassword = true;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showForgotPasswordBottomSheet(BuildContext context) {
    final langProvider = context.read<LanguageProvider>();
    final primaryColor = Theme.of(context).primaryColor;
    final TextEditingController resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    bool isSending = false;

    CustomBottomSheet.showContent(
      context: context,
      isScrollControlled: true,
      child: StatefulBuilder(
        builder: (modalContext, setModalState) {
          Future<void> submitReset() async {
            if (isSending) return;
            final email = resetEmailController.text.trim();
            if (email.isEmpty) {
              CustomSnackBar.showError(
                context: modalContext,
                message: langProvider.t('enter_email_for_reset'),
              );
              return;
            }
            setModalState(() => isSending = true);
            try {
              await modalContext.read<AuthProvider>().resetPassword(email);
              if (modalContext.mounted) {
                Navigator.pop(modalContext);
                CustomSnackBar.showSuccess(
                  context: context,
                  message: langProvider.t('reset_link_sent'),
                );
              }
            } catch (e) {
              if (modalContext.mounted) {
                CustomSnackBar.showError(
                  context: context,
                  message: e.toString().replaceAll('Exception: ', ''),
                );
              }
            } finally {
              if (modalContext.mounted) {
                setModalState(() => isSending = false);
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  langProvider.t('forgot_password'),
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  langProvider.t('enter_email_for_reset'),
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: resetEmailController,
                  style: const TextStyle(color: Colors.white),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => submitReset(),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: langProvider.t('email'),
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    prefixIcon:
                        Icon(Icons.email_outlined, color: Colors.grey.shade400),
                    filled: true,
                    fillColor: Colors.grey.shade800,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
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
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isSending ? null : submitReset,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: isSending
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5),
                                      )
                                    : Text(
                                        langProvider.t('send_link'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final textColor =
        primaryColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    final langProvider = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                langProvider.t('welcome'),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                langProvider.t('login_email_desc'),
                style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 48),
              // E-posta Kutucuğu
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: langProvider.t('email'),
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon:
                      Icon(Icons.email_outlined, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Şifre Kutucuğu
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: langProvider.t('password'),
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  prefixIcon:
                      Icon(Icons.lock_outline, color: Colors.grey.shade400),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey.shade400,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Theme(
                        data: ThemeData(
                            unselectedWidgetColor: Colors.grey.shade500),
                        child: Checkbox(
                          value: _rememberMe,
                          activeColor: primaryColor.withOpacity(0.7),
                          checkColor: Colors.white,
                          onChanged: (val) =>
                              setState(() => _rememberMe = val ?? false),
                        ),
                      ),
                      Text(langProvider.t('remember_me'),
                          style: TextStyle(color: Colors.grey.shade400)),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      _showForgotPasswordBottomSheet(context);
                    },
                    child: Text(
                      langProvider.t('forgot_password'),
                      style: TextStyle(
                          color: primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
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
                          onTap: _isLoading
                              ? null
                              : () async {
                                  final lang = context.read<LanguageProvider>();
                                  final email = _emailController.text.trim();
                                  final password =
                                      _passwordController.text.trim();

                                  if (email.isEmpty || password.isEmpty) {
                                    CustomSnackBar.showError(
                                      context: context,
                                      message: lang.t('enter_email_password'),
                                    );
                                    return;
                                  }

                                  setState(() => _isLoading = true);
                                  try {
                                    final authProvider =
                                        context.read<AuthProvider>();
                                    final user = await authProvider
                                        .signInWithEmailPassword(
                                            email, password);

                                    if (user != null && mounted) {
                                      context
                                          .read<SongProvider>()
                                          .fetchSongsFromApi();
                                      Navigator.of(context)
                                          .popUntil((route) => route.isFirst);
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      CustomSnackBar.showError(
                                        context: context,
                                        message: e
                                            .toString()
                                            .replaceAll('Exception: ', ''),
                                      );
                                    }
                                  } finally {
                                    if (mounted)
                                      setState(() => _isLoading = false);
                                  }
                                },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5),
                                    )
                                  : Text(
                                      langProvider.t('login'),
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    langProvider.t('no_account'),
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const RegisterPage()),
                      );
                    },
                    child: Text(
                      langProvider.t('register'),
                      style: TextStyle(
                          color: primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
