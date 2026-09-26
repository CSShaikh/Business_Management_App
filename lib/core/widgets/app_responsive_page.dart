import 'package:flutter/material.dart';

/// Shared page frame used by the business screens.
/// It follows the dashboard's centered, card-friendly layout while adapting
/// padding and maximum content width for phones, tablets and desktops.
class AppResponsivePage extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const AppResponsivePage({
    super.key,
    required this.child,
    this.maxWidth = 1180,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 600;
        final bool tablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1000;
        final double horizontal = compact ? 12 : (tablet ? 18 : 24);
        final double vertical = compact ? 10 : 18;
        final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    vertical,
                    horizontal,
                    vertical + (bottomInset > 0 ? 8 : 0),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
