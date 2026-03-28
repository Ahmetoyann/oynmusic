import 'dart:ui';
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
      color: Colors.black.withOpacity(0.75),
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.2), width: 1.5),
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
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: icon,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
