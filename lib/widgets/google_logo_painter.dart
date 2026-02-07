import 'package:flutter/material.dart';

class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // Canvas'ı 24x24'lük standart SVG koordinat sistemine ölçekle
    canvas.scale(width / 24, height / 24);

    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Mavi Kısım
    Path bluePath = Path();
    bluePath.moveTo(22.56, 12.25);
    bluePath.cubicTo(22.56, 11.47, 22.49, 10.72, 22.36, 10.0);
    bluePath.lineTo(12.0, 10.0);
    bluePath.lineTo(12.0, 14.26);
    bluePath.lineTo(17.92, 14.26);
    bluePath.cubicTo(17.66, 15.63, 16.88, 16.79, 15.71, 17.57);
    bluePath.lineTo(15.71, 20.34);
    bluePath.lineTo(19.28, 20.34);
    bluePath.cubicTo(21.36, 18.42, 22.56, 15.6, 22.56, 12.25);
    bluePath.close();

    paint.color = const Color(0xFF4285F4);
    canvas.drawPath(bluePath, paint);

    // Yeşil Kısım
    Path greenPath = Path();
    greenPath.moveTo(12.0, 23.0);
    greenPath.cubicTo(14.97, 23.0, 17.46, 22.02, 19.28, 20.34);
    greenPath.lineTo(15.71, 17.57);
    greenPath.cubicTo(14.73, 18.23, 13.48, 18.63, 12.0, 18.63);
    greenPath.cubicTo(9.14, 18.63, 6.71, 16.7, 5.84, 14.1);
    greenPath.lineTo(2.18, 14.1);
    greenPath.lineTo(2.18, 16.94);
    greenPath.cubicTo(3.99, 20.53, 7.7, 23.0, 12.0, 23.0);
    greenPath.close();

    paint.color = const Color(0xFF34A853);
    canvas.drawPath(greenPath, paint);

    // Sarı Kısım
    Path yellowPath = Path();
    yellowPath.moveTo(5.84, 14.1);
    yellowPath.cubicTo(5.62, 13.44, 5.49, 12.74, 5.49, 12.0);
    yellowPath.cubicTo(5.49, 11.26, 5.62, 10.56, 5.84, 9.9);
    yellowPath.lineTo(5.84, 7.07);
    yellowPath.lineTo(2.18, 7.07);
    yellowPath.cubicTo(1.43, 8.55, 1.0, 10.22, 1.0, 12.0);
    yellowPath.cubicTo(1.0, 13.78, 1.43, 15.45, 2.18, 16.94);
    yellowPath.lineTo(5.84, 14.1);
    yellowPath.close();

    paint.color = const Color(0xFFFBBC05);
    canvas.drawPath(yellowPath, paint);

    // Kırmızı Kısım
    Path redPath = Path();
    redPath.moveTo(12.0, 5.38);
    redPath.cubicTo(13.62, 5.38, 15.06, 5.94, 16.21, 7.02);
    redPath.lineTo(19.36, 3.87);
    redPath.cubicTo(17.45, 2.09, 14.97, 1.0, 12.0, 1.0);
    redPath.cubicTo(7.7, 1.0, 3.99, 3.47, 2.18, 7.07);
    redPath.lineTo(5.84, 9.9);
    redPath.cubicTo(6.71, 7.3, 9.14, 5.38, 12.0, 5.38);
    redPath.close();

    paint.color = const Color(0xFFEA4335);
    canvas.drawPath(redPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
