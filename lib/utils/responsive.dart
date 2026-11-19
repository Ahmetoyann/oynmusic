import 'package:flutter/material.dart';

/// Responsive ekran uyumluluğu yardımcısı.
/// Telefon dikey (portrait) modunda mevcut tasarımı birebir korur.
/// Tablet veya genişliği uzunluğundan büyük (landscape/geniş) ekranlarda
/// arayüzün zarif ve ergonomik bir kılıf gibi uyum sağlamasını yönetir.
class Responsive {
  /// Tablet veya Geniş (Genişliği > Yüksekliği) ekran kontrolü
  static bool isTabletOrLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width >= 600 || size.width > size.height;
  }

  /// Tablet ekran kontrolü (en kısa kenarı veya genişliği >= 600)
  static bool isTablet(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.shortestSide >= 600 || size.width >= 600;
  }

  /// Yatay mod kontrolü (Genişlik > Yükseklik)
  static bool isLandscape(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width > size.height;
  }

  /// Standart telefon dikey mod kontrolü (Mevcut durum)
  static bool isPhonePortrait(BuildContext context) {
    return !isTabletOrLandscape(context);
  }

  /// Ana sayfa (Trend) ile aynı içerik sütunu.
  /// Tablet ve yatay ekranda sayfalar bu genişliği aşmaz.
  static const double widePageMaxWidth = 950;

  /// Izgara ve kart hesabında kullanılacak içerik genişliği.
  /// Geniş ekranda [widePageMaxWidth] ile sınırlıdır.
  static double pageContentWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (isTabletOrLandscape(context) && width > widePageMaxWidth) {
      return widePageMaxWidth;
    }
    return width;
  }

  /// Izgaralar (Grid) için ekrana göre ideal sütun sayısını döner.
  /// [width] verilirse sütun sayısı tam ekran yerine bu genişliğe göre hesaplanır.
  static int gridColumns(
    BuildContext context, {
    int phone = 2,
    int tablet = 4,
    int wide = 5,
    double? width,
  }) {
    final resolved = width ?? MediaQuery.sizeOf(context).width;
    if (resolved >= 1100) return wide;
    if (resolved >= 600 ||
        (width == null && isTabletOrLandscape(context))) {
      return tablet;
    }
    return phone;
  }

  /// Tablet / yatay ekranda sayfayı diğer sekmelerle aynı genişlikte ortalar.
  /// Telefonda çocuğu olduğu gibi döndürür.
  static Widget limitPageWidth(BuildContext context, Widget child) {
    final width = MediaQuery.sizeOf(context).width;
    if (!isTabletOrLandscape(context) || width <= widePageMaxWidth) {
      return child;
    }
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: widePageMaxWidth,
        child: child,
      ),
    );
  }

  /// Geniş ekranlarda içeriğin aşırı esnemesini önleyip ortalayan sarmalayıcı
  static Widget centeredConstrained({
    required Widget child,
    double maxWidth = 720,
    Alignment alignment = Alignment.topCenter,
  }) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Scaffold.appBar için [Responsive.limitPageWidth] karşılığı.
/// Tablet / yatayda başlığı ve aksiyonları aynı içerik sütununa alır.
class LimitedWidthAppBar extends StatelessWidget implements PreferredSizeWidget {
  final PreferredSizeWidget child;

  const LimitedWidthAppBar({super.key, required this.child});

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    return Responsive.limitPageWidth(context, child);
  }
}
