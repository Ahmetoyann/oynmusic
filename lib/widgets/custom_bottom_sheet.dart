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
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => CustomBottomSheet(
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
    );
  }

  static Future<T?> showContent<T>({
    required BuildContext context,
    required Widget child,
    bool isScrollControlled = false,
    bool isDismissible = true,
    Color backgroundColor = Colors.black,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(child: child),
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
              child: ElevatedButton(
                onPressed: onPrimaryButtonTap ?? () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      primaryButtonColor ?? Theme.of(context).primaryColor,
                  foregroundColor: primaryButtonTextColor ?? Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  primaryButtonText!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
