import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Macronutrientes que muestra la app. Cada uno tiene siempre el mismo nombre,
/// ícono y color (guía visual, "Iconografía" y "Paleta").
enum Macro {
  calories('Calorías', Icons.local_fire_department_rounded),
  protein('Proteína', Icons.egg_alt_rounded),
  fat('Grasa', Icons.water_drop_rounded);

  const Macro(this.label, this.icon);

  final String label;
  final IconData icon;

  Color color(AppColors colors) => switch (this) {
    Macro.calories => colors.calories,
    Macro.protein => colors.protein,
    Macro.fat => colors.fat,
  };

  Color track(AppColors colors) => switch (this) {
    Macro.calories => colors.caloriesTrack,
    Macro.protein => colors.proteinTrack,
    Macro.fat => colors.fatTrack,
  };
}
