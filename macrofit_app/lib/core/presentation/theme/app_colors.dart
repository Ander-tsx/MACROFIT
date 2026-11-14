import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Paleta base de MacroFit (ver la guía en `lib/app/README.md`).
///
/// Inspirada en One UI: negro puro y grises cálidos en oscuro, grises claros
/// en claro, y tres colores vivos para los macronutrientes.
///
/// Es el **único** archivo con valores de color. El `ColorScheme` de `AppTheme` y la
/// extensión [AppColors] se arman con estos valores; las vistas solo leen el tema.
abstract final class AppPalette {
  // Neutros oscuros.
  static const black = Color(0xFF000000);
  static const night900 = Color(0xFF0B0B0D);
  static const night800 = Color(0xFF17171B);
  static const night700 = Color(0xFF222327);
  static const night600 = Color(0xFF2D2E33);
  static const night500 = Color(0xFF3B3C42);
  static const night400 = Color(0xFF5C5D64);
  static const night300 = Color(0xFF9C9CA3);

  // Neutros claros.
  static const white = Color(0xFFFFFFFF);
  static const day100 = Color(0xFFF2F2F5);
  static const day200 = Color(0xFFEBEBF0);
  static const day300 = Color(0xFFE1E1E7);
  static const day400 = Color(0xFFCFCFD6);
  static const day500 = Color(0xFF66666E);
  static const ink = Color(0xFF111114);
  static const snow = Color(0xFFF4F4F6);

  // Calorías: verde.
  static const green300 = Color(0xFF8BD448);
  static const green700 = Color(0xFF2F750B);
  static const greenDeep = Color(0xFF24381A);
  static const greenSoft = Color(0xFFE3F3D6);

  // Proteína: cian.
  static const cyan300 = Color(0xFF2CC6EE);
  static const cyan700 = Color(0xFF0A7FAA);
  static const cyanDeep = Color(0xFF12313B);
  static const cyanSoft = Color(0xFFD9F1F9);

  // Grasa: morado.
  static const purple300 = Color(0xFFB76CFF);
  static const purple700 = Color(0xFF8338D6);
  static const purpleDeep = Color(0xFF2E1E40);
  static const purpleSoft = Color(0xFFEEE1FB);

  // Advertencia: ámbar.
  static const amber300 = Color(0xFFFFC24D);
  static const amber700 = Color(0xFF9A5F00);
  static const amberDeep = Color(0xFF3A2A0C);
  static const amberSoft = Color(0xFFFFF1D6);

  // Error: rojo coral.
  static const red300 = Color(0xFFFF6B6B);
  static const red700 = Color(0xFFD3303B);
  static const redDeep = Color(0xFF3A1416);
  static const redSoft = Color(0xFFFDE4E5);

  // Tarjetas destacadas (degradados).
  static const forest600 = Color(0xFF0E6B52);
  static const forest400 = Color(0xFF13795E);
  static const ocean600 = Color(0xFF145DB8);
  static const ocean400 = Color(0xFF1A6FC8);

  // Fondo del inicio: resplandor azul noche arriba.
  static const navyGlow = Color(0xFF0F2347);
  static const skyGlow = Color(0xFFDCE6F7);

  static const shadow = Color(0xFF000000);
  static const transparent = Color(0x00000000);
}

/// Colores semánticos que el `ColorScheme` de Material no cubre: macronutrientes,
/// estados (éxito, advertencia, información), tarjetas destacadas y la barra
/// flotante.
///
/// Se leen con `context.appColors` (ver `theme_context.dart`).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.calories,
    required this.caloriesTrack,
    required this.protein,
    required this.proteinTrack,
    required this.fat,
    required this.fatTrack,
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
    required this.featureGreen,
    required this.featureGreenLight,
    required this.featureBlue,
    required this.featureBlueLight,
    required this.onFeature,
    required this.glow,
    required this.shadow,
  });

  /// Macronutrientes: siempre el mismo color en toda la app (anillos, barras, etiquetas).
  final Color calories;
  final Color caloriesTrack;
  final Color protein;
  final Color proteinTrack;
  final Color fat;
  final Color fatTrack;

  /// Estados.
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color infoContainer;
  final Color onInfoContainer;

  /// Superficie oscura flotante (barra inferior, avisos).
  final Color hero;
  final Color onHero;
  final Color onHeroMuted;
  final Color heroGlass;

  /// Acento de marca: botón principal de la barra y resaltados.
  final Color accent;
  final Color onAccent;

  /// Tarjetas destacadas: degradado de dos tonos y texto blanco.
  final Color featureGreen;
  final Color featureGreenLight;
  final Color featureBlue;
  final Color featureBlueLight;
  final Color onFeature;

  /// Resplandor superior del fondo del inicio.
  final Color glow;
  final Color shadow;

  static const light = AppColors(
    calories: AppPalette.green700,
    caloriesTrack: AppPalette.greenSoft,
    protein: AppPalette.cyan700,
    proteinTrack: AppPalette.cyanSoft,
    fat: AppPalette.purple700,
    fatTrack: AppPalette.purpleSoft,
    success: AppPalette.green700,
    successContainer: AppPalette.greenSoft,
    onSuccessContainer: AppPalette.green700,
    warning: AppPalette.amber700,
    warningContainer: AppPalette.amberSoft,
    onWarningContainer: AppPalette.amber700,
    info: AppPalette.cyan700,
    infoContainer: AppPalette.cyanSoft,
    onInfoContainer: AppPalette.cyan700,
    hero: AppPalette.night700,
    onHero: AppPalette.snow,
    onHeroMuted: AppPalette.night300,
    heroGlass: AppPalette.night600,
    accent: AppPalette.green300,
    onAccent: AppPalette.ink,
    featureGreen: AppPalette.forest600,
    featureGreenLight: AppPalette.forest400,
    featureBlue: AppPalette.ocean600,
    featureBlueLight: AppPalette.ocean400,
    onFeature: AppPalette.white,
    glow: AppPalette.skyGlow,
    shadow: AppPalette.shadow,
  );

  static const dark = AppColors(
    calories: AppPalette.green300,
    caloriesTrack: AppPalette.greenDeep,
    protein: AppPalette.cyan300,
    proteinTrack: AppPalette.cyanDeep,
    fat: AppPalette.purple300,
    fatTrack: AppPalette.purpleDeep,
    success: AppPalette.green300,
    successContainer: AppPalette.greenDeep,
    onSuccessContainer: AppPalette.green300,
    warning: AppPalette.amber300,
    warningContainer: AppPalette.amberDeep,
    onWarningContainer: AppPalette.amber300,
    info: AppPalette.cyan300,
    infoContainer: AppPalette.cyanDeep,
    onInfoContainer: AppPalette.cyan300,
    hero: AppPalette.night600,
    onHero: AppPalette.snow,
    onHeroMuted: AppPalette.night300,
    heroGlass: AppPalette.night500,
    accent: AppPalette.green300,
    onAccent: AppPalette.ink,
    featureGreen: AppPalette.forest600,
    featureGreenLight: AppPalette.forest400,
    featureBlue: AppPalette.ocean600,
    featureBlueLight: AppPalette.ocean400,
    onFeature: AppPalette.white,
    glow: AppPalette.navyGlow,
    shadow: AppPalette.shadow,
  );

  @override
  AppColors copyWith({
    Color? calories,
    Color? caloriesTrack,
    Color? protein,
    Color? proteinTrack,
    Color? fat,
    Color? fatTrack,
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
    Color? featureGreen,
    Color? featureGreenLight,
    Color? featureBlue,
    Color? featureBlueLight,
    Color? onFeature,
    Color? glow,
    Color? shadow,
  }) => AppColors(
    calories: calories ?? this.calories,
    caloriesTrack: caloriesTrack ?? this.caloriesTrack,
    protein: protein ?? this.protein,
    proteinTrack: proteinTrack ?? this.proteinTrack,
    fat: fat ?? this.fat,
    fatTrack: fatTrack ?? this.fatTrack,
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
    featureGreen: featureGreen ?? this.featureGreen,
    featureGreenLight: featureGreenLight ?? this.featureGreenLight,
    featureBlue: featureBlue ?? this.featureBlue,
    featureBlueLight: featureBlueLight ?? this.featureBlueLight,
    onFeature: onFeature ?? this.onFeature,
    glow: glow ?? this.glow,
    shadow: shadow ?? this.shadow,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      calories: mix(calories, other.calories),
      caloriesTrack: mix(caloriesTrack, other.caloriesTrack),
      protein: mix(protein, other.protein),
      proteinTrack: mix(proteinTrack, other.proteinTrack),
      fat: mix(fat, other.fat),
      fatTrack: mix(fatTrack, other.fatTrack),
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
      featureGreen: mix(featureGreen, other.featureGreen),
      featureGreenLight: mix(featureGreenLight, other.featureGreenLight),
      featureBlue: mix(featureBlue, other.featureBlue),
      featureBlueLight: mix(featureBlueLight, other.featureBlueLight),
      onFeature: mix(onFeature, other.onFeature),
      glow: mix(glow, other.glow),
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
