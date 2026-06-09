import 'dart:ui';
import 'package:flutter/material.dart';

class CustomBottomSheet extends StatelessWidget {
  final String? title;
  final String? message;
  final Widget? icon;
  final String? primaryButtonText;
  final VoidCallback? onPrimaryButtonTap;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryButtonTap;
  final Color? primaryButtonColor;
  final Color? primaryButtonTextColor;
  final Widget? child;

  const CustomBottomSheet({
    super.key,
    this.title,
    this.message,
    this.icon,
    this.primaryButtonText,
    this.onPrimaryButtonTap,
    this.secondaryButtonText,
    this.onSecondaryButtonTap,
    this.primaryButtonColor,
    this.primaryButtonTextColor,
    this.child,
  });

  /// Statik metod ile hızlı kullanım sağlar.
  /// Örnek: CustomBottomSheet.show(context: context, title: "Hata", message: "Bir sorun oluştu.");
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    Widget? icon,
    String? primaryButtonText,
    VoidCallback? onPrimaryButtonTap,
    String? secondaryButtonText,
    VoidCallback? onSecondaryButtonTap,
    Color? primaryButtonColor,
    Color? primaryButtonTextColor,
    bool isDismissible = true,
  }) {
    return showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: isDismissible,
      barrierLabel: 'CustomDialog',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: isDismissible ? () => Navigator.pop(context) : null,
                  child: Container(color: Colors.transparent),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: 24,
                      left: 16,
                      right: 16,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: CustomBottomSheet(
                            title: title,
                            message: message,
                            icon: icon,
                            primaryButtonText: primaryButtonText,
                            onPrimaryButtonTap: onPrimaryButtonTap,
                            secondaryButtonText: secondaryButtonText,
                            onSecondaryButtonTap: onSecondaryButtonTap,
                            primaryButtonColor: primaryButtonColor,
                            primaryButtonTextColor: primaryButtonTextColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final blurredBackground = Container(
          color: Colors.black.withOpacity(0.75 * animation.value),
        );

        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );

        return Stack(
          children: [
            blurredBackground,
            SlideTransition(position: slideAnimation, child: child),
          ],
        );
      },
    );
  }

  static Future<T?> showContent<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = false,
    bool isDismissible = true,
    Color? backgroundColor,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: isDismissible,
      barrierLabel: 'CustomContentDialog',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: isDismissible ? () => Navigator.pop(context) : null,
                  child: Container(color: Colors.transparent),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: 24,
                      left: 16,
                      right: 16,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.85,
                        ),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: backgroundColor ?? Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(16),
                          border: backgroundColor == Colors.transparent
                              ? null
                              : Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1.2,
                                ),
                          boxShadow: backgroundColor == Colors.transparent
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final blurredBackground = Container(
          color: Colors.black.withOpacity(0.75 * animation.value),
        );

        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );

        return Stack(
          children: [
            blurredBackground,
            SlideTransition(position: slideAnimation, child: child),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (child != null) return child!;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon!, const SizedBox(height: 16)],
          if (title != null)
            Text(
              title!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
            ),
          ],
          const SizedBox(height: 24),
          if (primaryButtonText != null)
            SizedBox(
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        (primaryButtonColor ?? Theme.of(context).primaryColor)
                            .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          (primaryButtonColor ?? Theme.of(context).primaryColor)
                              .withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (primaryButtonColor ??
                                Theme.of(context).primaryColor)
                            .withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onPrimaryButtonTap ?? () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            primaryButtonText!,
                            style: TextStyle(
                              color: primaryButtonTextColor ?? Colors.white,
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
          if (secondaryButtonText != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onSecondaryButtonTap ?? () => Navigator.pop(context),
              child: Text(
                secondaryButtonText!,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
