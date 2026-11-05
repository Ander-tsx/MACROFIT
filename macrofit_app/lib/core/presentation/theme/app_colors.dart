import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Paleta base de MacroFit (ver la guía en `lib/app/README.md`).
///
/// Es el **único** archivo con valores de color. El `ColorScheme` de `AppTheme` y la
/// extensión [AppColors] se arman con estos valores; las vistas solo leen el tema.
abstract final class AppPalette {
  // Tinta (texto y botones principales en claro, fondos en oscuro).
  static const ink950 = Color(0xFF0B0D10);
  static const ink900 = Color(0xFF121315);
  static const ink850 = Color(0xFF15181C);
  static const ink800 = Color(0xFF1C2025);
  static const ink700 = Color(0xFF262B32);
  static const ink600 = Color(0xFF353B44);
  static const ink500 = Color(0xFF63666D);
  static const ink400 = Color(0xFF8A939E);
  static const ink300 = Color(0xFFA9B1BB);

  // Neutros fríos (fondos en claro).
  static const mist50 = Color(0xFFFFFFFF);
  static const mist100 = Color(0xFFF4F4F1);
  static const mist200 = Color(0xFFEDEDE9);
  static const mist300 = Color(0xFFE4E4DF);
  static const mist400 = Color(0xFFD6D6D0);
  static const mist500 = Color(0xFFC2C2BB);

  // Verde de marca: progreso, éxito y calorías.
  static const green900 = Color(0xFF0B4A26);
  static const green800 = Color(0xFF12371F);
  static const green700 = Color(0xFF15803D);
  static const green500 = Color(0xFF22A55B);
  static const green400 = Color(0xFF4ADE80);
  static const green200 = Color(0xFFBBF7D0);
  static const green100 = Color(0xFFDCF5E5);
  static const lime300 = Color(0xFFC6F36B);

  // Azul: proteína e información.
  static const blue900 = Color(0xFF173A7A);
  static const blue800 = Color(0xFF14284D);
  static const blue600 = Color(0xFF2563EB);
  static const blue400 = Color(0xFF60A5FA);
  static const blue200 = Color(0xFFBFDBFE);
  static const blue100 = Color(0xFFE2ECFF);

  // Ámbar: grasa y advertencias.
  static const amber900 = Color(0xFF7A4A06);
  static const amber800 = Color(0xFF3D2A0A);
  static const amber600 = Color(0xFFD97706);
  static const amber400 = Color(0xFFFBBF24);
  static const amber200 = Color(0xFFFDE68A);
  static const amber100 = Color(0xFFFEF3C7);

  // Rojo: errores y acciones destructivas.
  static const red900 = Color(0xFF8A1C1C);
  static const red800 = Color(0xFF3B1414);
  static const red600 = Color(0xFFC62828);
  static const red400 = Color(0xFFF87171);
  static const red200 = Color(0xFFFECACA);
  static const red100 = Color(0xFFFDE7E7);

  static const shadow = Color(0xFF0B0D10);
  static const transparent = Color(0x00000000);
}

/// Colores semánticos que el `ColorScheme` de Material no cubre: macronutrientes,
/// estados (éxito, advertencia, información) y el encabezado oscuro.
///
/// Se leen con `context.appColors` (ver `theme_context.dart`).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.calories,
    required this.caloriesContainer,
    required this.protein,
    required this.proteinContainer,
    required this.fat,
    required this.fatContainer,
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.hero,
    required this.onHero,
    required this.onHeroMuted,
    required this.heroGlass,
    required this.accent,
    required this.onAccent,
    required this.shadow,
  });

  /// Macronutrientes: siempre el mismo color en toda la app.
  final Color calories;
  final Color caloriesContainer;
  final Color protein;
  final Color proteinContainer;
  final Color fat;
  final Color fatContainer;

  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color infoContainer;
  final Color onInfoContainer;

  /// Encabezado oscuro de las pantallas principales y de la autenticación.
  final Color hero;
  final Color onHero;
  final Color onHeroMuted;
  final Color heroGlass;

  /// Acento de marca (lima) para resaltar sobre fondos oscuros.
  final Color accent;
  final Color onAccent;

  final Color shadow;

  static const light = AppColors(
    calories: AppPalette.green500,
    caloriesContainer: AppPalette.green100,
    protein: AppPalette.blue600,
    proteinContainer: AppPalette.blue100,
    fat: AppPalette.amber600,
    fatContainer: AppPalette.amber100,
    success: AppPalette.green700,
    successContainer: AppPalette.green100,
    onSuccessContainer: AppPalette.green900,
    warning: AppPalette.amber600,
    warningContainer: AppPalette.amber100,
    onWarningContainer: AppPalette.amber900,
    info: AppPalette.blue600,
    infoContainer: AppPalette.blue100,
    onInfoContainer: AppPalette.blue900,
    hero: AppPalette.ink900,
    onHero: AppPalette.mist50,
    onHeroMuted: AppPalette.ink300,
    heroGlass: AppPalette.ink700,
    accent: AppPalette.lime300,
    onAccent: AppPalette.ink900,
    shadow: AppPalette.shadow,
  );

  static const dark = AppColors(
    calories: AppPalette.green400,
    caloriesContainer: AppPalette.green800,
    protein: AppPalette.blue400,
    proteinContainer: AppPalette.blue800,
    fat: AppPalette.amber400,
    fatContainer: AppPalette.amber800,
    success: AppPalette.green400,
    successContainer: AppPalette.green800,
    onSuccessContainer: AppPalette.green200,
    warning: AppPalette.amber400,
    warningContainer: AppPalette.amber800,
    onWarningContainer: AppPalette.amber200,
    info: AppPalette.blue400,
    infoContainer: AppPalette.blue800,
    onInfoContainer: AppPalette.blue200,
    hero: AppPalette.ink850,
    onHero: AppPalette.mist100,
    onHeroMuted: AppPalette.ink300,
    heroGlass: AppPalette.ink700,
    accent: AppPalette.lime300,
    onAccent: AppPalette.ink900,
    shadow: AppPalette.shadow,
  );

  @override
  AppColors copyWith({
    Color? calories,
    Color? caloriesContainer,
    Color? protein,
    Color? proteinContainer,
    Color? fat,
    Color? fatContainer,
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? hero,
    Color? onHero,
    Color? onHeroMuted,
    Color? heroGlass,
    Color? accent,
    Color? onAccent,
    Color? shadow,
  }) => AppColors(
    calories: calories ?? this.calories,
    caloriesContainer: caloriesContainer ?? this.caloriesContainer,
    protein: protein ?? this.protein,
    proteinContainer: proteinContainer ?? this.proteinContainer,
    fat: fat ?? this.fat,
    fatContainer: fatContainer ?? this.fatContainer,
    success: success ?? this.success,
    successContainer: successContainer ?? this.successContainer,
    onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
    warning: warning ?? this.warning,
    warningContainer: warningContainer ?? this.warningContainer,
    onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    info: info ?? this.info,
    infoContainer: infoContainer ?? this.infoContainer,
    onInfoContainer: onInfoContainer ?? this.onInfoContainer,
    hero: hero ?? this.hero,
    onHero: onHero ?? this.onHero,
    onHeroMuted: onHeroMuted ?? this.onHeroMuted,
    heroGlass: heroGlass ?? this.heroGlass,
    accent: accent ?? this.accent,
    onAccent: onAccent ?? this.onAccent,
    shadow: shadow ?? this.shadow,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      calories: mix(calories, other.calories),
      caloriesContainer: mix(caloriesContainer, other.caloriesContainer),
      protein: mix(protein, other.protein),
      proteinContainer: mix(proteinContainer, other.proteinContainer),
      fat: mix(fat, other.fat),
      fatContainer: mix(fatContainer, other.fatContainer),
      success: mix(success, other.success),
      successContainer: mix(successContainer, other.successContainer),
      onSuccessContainer: mix(onSuccessContainer, other.onSuccessContainer),
      warning: mix(warning, other.warning),
      warningContainer: mix(warningContainer, other.warningContainer),
      onWarningContainer: mix(onWarningContainer, other.onWarningContainer),
      info: mix(info, other.info),
      infoContainer: mix(infoContainer, other.infoContainer),
      onInfoContainer: mix(onInfoContainer, other.onInfoContainer),
      hero: mix(hero, other.hero),
      onHero: mix(onHero, other.onHero),
      onHeroMuted: mix(onHeroMuted, other.onHeroMuted),
      heroGlass: mix(heroGlass, other.heroGlass),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      shadow: mix(shadow, other.shadow),
    );
  }
}

/// Sombras suaves: en claro dan profundidad sin bordes; en oscuro casi no se ven
/// y las superficies se distinguen por su color.
abstract final class AppShadows {
  static List<BoxShadow> soft(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: AppPalette.shadow.withValues(
          alpha: dark ? AppOpacity.shadowDark : AppOpacity.shadow,
        ),
        blurRadius: AppElevation.softBlur,
        offset: const Offset(0, AppElevation.softOffset),
      ),
    ];
  }

  static List<BoxShadow> floating(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: AppPalette.shadow.withValues(
          alpha: (dark ? AppOpacity.shadowDark : AppOpacity.shadow) * 2,
        ),
        blurRadius: AppElevation.floatingBlur,
        offset: const Offset(0, AppElevation.floatingOffset),
      ),
    ];
  }
}
