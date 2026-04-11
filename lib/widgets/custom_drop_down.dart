import 'package:flutter/material.dart';

/// Merkezi ve özelleştirilebilir açılır menü (Dropdown) bileşeni
class CustomDropDown<T> extends StatelessWidget {
  final Widget icon;
  final String tooltip;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;

  const CustomDropDown({
    super.key,
    required this.icon,
    required this.items,
    required this.onSelected,
    this.tooltip = "Seçenekler",
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      icon: icon,
      tooltip: tooltip,
      color: const Color(
        0xFF1C1C1E,
      ).withOpacity(0.98), // Uygulamanın modern koyu temasıyla uyumlu
      surfaceTintColor: Colors
          .transparent, // Material 3'ün istenmeyen renk katmanını engeller
      elevation: 12, // Derinlik hissini artırdık
      shadowColor: Colors.black.withOpacity(0.5),
      position: PopupMenuPosition
          .under, // Menünün tıklanan butonun altında açılmasını sağlar
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          20,
        ), // Uygulamadaki diğer yuvarlatılmış köşelerle uyumlu
        side: BorderSide(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ), // Daha zarif bir kenarlık
      ),
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => items,
    );
  }
}

/// Dropdown içindeki elemanları standartlaştırmak için yardımcı sınıf
class CustomDropdownItem {
  static PopupMenuItem<T> build<T>({
    required BuildContext context,
    required T value,
    required Widget icon,
    required String text,
    Color textColor = Colors.white,
  }) {
    return PopupMenuItem<T>(
      value: value,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ), // Tıklama alanı ve boşluklar iyileştirildi
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).primaryColor.withOpacity(0.15), // Daha soft bir arka plan
              borderRadius: BorderRadius.circular(12),
            ),
            child: icon,
          ),
          const SizedBox(width: 16),
          Expanded(
            // Uzun metinlerin taşmasını engeller
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight
                    .w600, // Aşırı kalın (bold) yerine daha zarif bir kalınlık
                fontSize: 15,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
