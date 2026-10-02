import 'package:flutter/material.dart';

/// Tema base de la app. El color semilla es provisional hasta tener la guía visual.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF2E7D32);

  static final ThemeData light = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed),
    useMaterial3: true,
  );

  static final ThemeData dark = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );
}
