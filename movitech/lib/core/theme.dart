import 'package:flutter/material.dart';

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3F6FD8), brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 1,
    ),
    inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none),
  );
}
