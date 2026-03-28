import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final bool centerTitle;
  final Widget? leading;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final double elevation;
  final TextStyle? titleStyle;
  final bool showLeading;
  final PreferredSizeWidget? bottom;
  final bool wrapActionsInBox;
  final double? titleSpacing;
  final bool wrapLeadingInBox;

  const CustomAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.centerTitle = false,
    this.leading,
    this.actions,
    this.backgroundColor,
    this.elevation = 0,
    this.titleStyle,
    this.showLeading = true,
    this.bottom,
    this.wrapActionsInBox = true,
    this.titleSpacing,
    this.wrapLeadingInBox = true,
  }) : assert(
         title == null || titleWidget == null,
         'Cannot provide both a title and a titleWidget',
       ),
       assert(
         title != null || titleWidget != null,
         'Must provide either a title or a titleWidget',
       );

  @override
  Widget build(BuildContext context) {
    Widget? effectiveLeading = leading;
    if (effectiveLeading == null &&
        showLeading &&
        Navigator.of(context).canPop()) {
      effectiveLeading = const BackButton();
    }

    return AppBar(
      iconTheme: IconThemeData(color: Theme.of(context).primaryColor),
      actionsIconTheme: IconThemeData(color: Theme.of(context).primaryColor),
      title:
          titleWidget ??
          Text(
            title!,
            style:
                titleStyle ??
                TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  color: Theme.of(context).primaryColor,
                ),
          ),
      centerTitle: centerTitle,
      titleSpacing: titleSpacing,
      leading: effectiveLeading != null
          ? (wrapLeadingInBox
                ? _AppBarIconBox(child: effectiveLeading)
                : effectiveLeading)
          : null,
      automaticallyImplyLeading: false,
      actions: wrapActionsInBox
          ? actions
                ?.map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _AppBarIconBox(child: action),
                  ),
                )
                .toList()
          : actions,
      backgroundColor: backgroundColor ?? Colors.black,
      elevation: elevation,
      scrolledUnderElevation: 0,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}

class _AppBarIconBox extends StatelessWidget {
  final Widget child;
  const _AppBarIconBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.transparent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: IconTheme(
          data: IconThemeData(color: Theme.of(context).primaryColor, size: 27),
          child: child,
        ),
      ),
    );
  }
}
