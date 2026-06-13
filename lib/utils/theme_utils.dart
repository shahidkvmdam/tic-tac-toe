import 'package:flutter/material.dart';

/// Returns the correct background BoxDecoration for any screen,
/// adapting to dark (black) or light (soft purple) theme.
BoxDecoration appBackground(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [Color(0xFF0D0D0D), Color(0xFF1A1A2E), Color(0xFF0D0D0D)]
          : const [Color(0xFFEDE9FE), Color(0xFFDDD6FE), Color(0xFFF5F3FF)],
    ),
  );
}

/// Foreground color for text/icons — white in dark, dark purple in light.
Color fgColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? Colors.white
      : const Color(0xFF1E1B4B);
}

/// Subtle foreground (60% opacity of fgColor).
Color fgSubtle(BuildContext context) => fgColor(context).withValues(alpha: 0.6);

/// Card/surface color.
Color cardColor(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.black.withValues(alpha: 0.05);
}

/// Card border color.
Color cardBorder(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return dark
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.black.withValues(alpha: 0.1);
}
