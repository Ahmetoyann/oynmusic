import 'dart:ui';
import 'package:flutter/material.dart';

class HeroLoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;

  const HeroLoadingIndicator({
    super.key,
    this.message,
    this.size = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          color: Colors.black.withOpacity(0.2),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Dış zarda dönen beyaz indikatör
                  SizedBox(
                    width: size + 20,
                    height: size + 20,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                  // Ortada sabit duran logo
                  Image.asset(
                    'assets/icon/OYN_ana_logo_seffaf.png',
                    height: size,
                    width: size,
                    color: primaryColor,
                  ),
                ],
              ),
              if (message != null) ...[
                const SizedBox(height: 24),
                Text(
                  message!,
                  style: TextStyle(
                      color: primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4,
                        )
                      ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
