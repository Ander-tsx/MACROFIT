import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'lucide_icons.dart';

/// Macronutrientes que muestra la app. Cada uno tiene siempre el mismo nombre,
/// ícono y color (guía visual, "Iconografía" y "Paleta").
enum Macro {
  calories('Calorías', LucideIcons.flame),
  protein('Proteína', LucideIcons.egg),
  fat('Grasa', LucideIcons.droplet);

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
