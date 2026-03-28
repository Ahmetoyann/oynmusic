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
    return showModalBottomSheet(
      context: context,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
            ),
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
    );
  }

  static Future<T?> showContent<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = false,
    bool isDismissible = true,
    Color? backgroundColor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.black.withOpacity(0.6),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
            ),
            child: SafeArea(child: child),
          ),
        ),
      ),
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
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          (primaryButtonColor ?? Theme.of(context).primaryColor)
                              .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            (primaryButtonColor ??
                                    Theme.of(context).primaryColor)
                                .withOpacity(0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (primaryButtonColor ??
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
                        onTap:
                            onPrimaryButtonTap ?? () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(16),
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
