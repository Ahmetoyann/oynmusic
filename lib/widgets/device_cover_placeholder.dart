import 'package:flutter/material.dart';

/// Reusable placeholder for device/local song covers.
/// Use `DeviceCoverPlaceholder(width: 100, height: 100)` or leave sizes null
/// for flexible sizing.
class DeviceCoverPlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final Color backgroundColor;
  final Color logoColor;

  const DeviceCoverPlaceholder({
    Key? key,
    this.width,
    this.height,
    this.borderRadius = 8.0,
    this.backgroundColor = Colors.black,
    this.logoColor = Colors.amber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Image.asset(
          'assets/icon/OYN_ana_logo_seffaf.png',
          color: logoColor,
          width: (width ?? 48) * 0.6,
          height: (height ?? 48) * 0.6,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
