import 'package:flutter/material.dart';

/// Background gradient — purple (default/light) or black (dark/moon).
BoxDecoration appBackground(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [Color(0xFF000000), Color(0xFF0D0D0D), Color(0xFF000000)]
          : const [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF0F172A)],
    ),
  );
}
