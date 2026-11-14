import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Atajos para leer el tema desde las vistas: `context.colors`, `context.text`
/// y `context.appColors`.
extension ThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;

  /// Colores semánticos de MacroFit (macros, estados y encabezado oscuro).
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColors.dark
          : AppColors.light);
}
