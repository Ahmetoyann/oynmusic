import 'package:flutter/material.dart';
import 'package:muzik_app/custom_icons.dart';

class CustomSearchBar extends StatelessWidget {
  static const double cornerRadius =
      6.0; // Tüm arama çubuklarının kavisini tek yerden yönetin

  final TextEditingController controller;
  final String hintText;
  final TextStyle? hintStyle;
  final TextStyle? textStyle;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool showClearButton;
  final Widget? extraSuffix;
  final Color? fillColor;
  final bool autofocus;
  final EdgeInsetsGeometry contentPadding;
  final Widget? prefixIcon;

  const CustomSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.hintStyle,
    this.textStyle,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.showClearButton = false,
    this.extraSuffix,
    this.fillColor,
    this.autofocus = false,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 0),
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      style: textStyle ?? const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: hintStyle ?? TextStyle(color: Colors.grey.shade400),
        prefixIcon: prefixIcon ??
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: CustomIcons.svgIcon(
                CustomIcons.search,
                color: Colors.grey,
                size: 24,
              ),
            ),
        filled: fillColor != Colors.transparent,
        fillColor: fillColor ?? Colors.grey.shade900,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
          borderSide: BorderSide.none,
        ),
        contentPadding: contentPadding,
        suffixIcon: _buildSuffixIcon(),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }

  Widget? _buildSuffixIcon() {
    if (!showClearButton && extraSuffix == null) return null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showClearButton)
          IconButton(
            icon: CustomIcons.svgIcon(
              CustomIcons.clear,
              color: Colors.grey,
              size: 24,
            ),
            onPressed: () {
              controller.clear();
              if (onClear != null) {
                onClear!();
              }
            },
          ),
        if (extraSuffix != null) extraSuffix!,
      ],
    );
  }
}
