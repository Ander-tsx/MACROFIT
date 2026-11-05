import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/presentation/theme/app_colors.dart';
import '../core/presentation/theme/app_tokens.dart';

/// Tema de MacroFit (claro y oscuro) construido a partir de la guía visual
/// documentada en `lib/app/README.md`.
///
/// - Colores: `AppPalette` → [ColorScheme] propio + extensión [AppColors].
/// - Tipografía: Inter (`assets/fonts/inter`), escala en [_textTheme].
/// - Medidas: `AppSpacing`, `AppRadius` y `AppSizes` (`app_tokens.dart`).
abstract final class AppTheme {
  /// Familia tipográfica declarada en `pubspec.yaml`.
  static const fontFamily = 'Inter';

  static final ThemeData light = _build(_lightScheme, AppColors.light);
  static final ThemeData dark = _build(_darkScheme, AppColors.dark);

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.ink900,
    onPrimary: AppPalette.mist50,
    primaryContainer: AppPalette.mist300,
    onPrimaryContainer: AppPalette.ink900,
    secondary: AppPalette.green700,
    onSecondary: AppPalette.mist50,
    secondaryContainer: AppPalette.green100,
    onSecondaryContainer: AppPalette.green900,
    tertiary: AppPalette.blue600,
    onTertiary: AppPalette.mist50,
    tertiaryContainer: AppPalette.blue100,
    onTertiaryContainer: AppPalette.blue900,
    error: AppPalette.red600,
    onError: AppPalette.mist50,
    errorContainer: AppPalette.red100,
    onErrorContainer: AppPalette.red900,
    surface: AppPalette.mist50,
    onSurface: AppPalette.ink900,
    onSurfaceVariant: AppPalette.ink500,
    surfaceDim: AppPalette.mist200,
    surfaceBright: AppPalette.mist50,
    surfaceContainerLowest: AppPalette.mist50,
    surfaceContainerLow: AppPalette.mist100,
    surfaceContainer: AppPalette.mist200,
    surfaceContainerHigh: AppPalette.mist300,
    surfaceContainerHighest: AppPalette.mist400,
    outline: AppPalette.mist500,
    outlineVariant: AppPalette.mist300,
    shadow: AppPalette.shadow,
    scrim: AppPalette.shadow,
    inverseSurface: AppPalette.ink900,
    onInverseSurface: AppPalette.mist100,
    inversePrimary: AppPalette.lime300,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.mist100,
    onPrimary: AppPalette.ink900,
    primaryContainer: AppPalette.ink700,
    onPrimaryContainer: AppPalette.mist100,
    secondary: AppPalette.green400,
    onSecondary: AppPalette.ink950,
    secondaryContainer: AppPalette.green800,
    onSecondaryContainer: AppPalette.green200,
    tertiary: AppPalette.blue400,
    onTertiary: AppPalette.ink950,
    tertiaryContainer: AppPalette.blue800,
    onTertiaryContainer: AppPalette.blue200,
    error: AppPalette.red400,
    onError: AppPalette.ink950,
    errorContainer: AppPalette.red800,
    onErrorContainer: AppPalette.red200,
    surface: AppPalette.ink850,
    onSurface: AppPalette.mist100,
    onSurfaceVariant: AppPalette.ink300,
    surfaceDim: AppPalette.ink950,
    surfaceBright: AppPalette.ink700,
    surfaceContainerLowest: AppPalette.ink950,
    surfaceContainerLow: AppPalette.ink950,
    surfaceContainer: AppPalette.ink800,
    surfaceContainerHigh: AppPalette.ink700,
    surfaceContainerHighest: AppPalette.ink600,
    outline: AppPalette.ink600,
    outlineVariant: AppPalette.ink700,
    shadow: AppPalette.shadow,
    scrim: AppPalette.shadow,
    inverseSurface: AppPalette.mist100,
    onInverseSurface: AppPalette.ink900,
    inversePrimary: AppPalette.ink900,
  );

  /// Escala tipográfica (Inter). Títulos con interletrado negativo, como en la
  /// referencia; cuerpo con alto de línea cómodo para lectura.
  static TextTheme _textTheme(ColorScheme scheme) {
    TextStyle style(
      double size,
      FontWeight weight, {
      double spacing = 0,
      double height = 1.3,
      Color? color,
    }) => TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: spacing,
      height: height,
      color: color ?? scheme.onSurface,
    );

    return TextTheme(
      displayLarge: style(48, FontWeight.w700, spacing: -1.6, height: 1.05),
      displayMedium: style(40, FontWeight.w700, spacing: -1.2, height: 1.1),
      displaySmall: style(34, FontWeight.w700, spacing: -1, height: 1.1),
      headlineLarge: style(30, FontWeight.w700, spacing: -0.8, height: 1.15),
      headlineMedium: style(26, FontWeight.w700, spacing: -0.6, height: 1.2),
      headlineSmall: style(22, FontWeight.w600, spacing: -0.4, height: 1.25),
      titleLarge: style(20, FontWeight.w600, spacing: -0.3),
      titleMedium: style(16, FontWeight.w600, spacing: -0.1),
      titleSmall: style(14, FontWeight.w600),
      bodyLarge: style(16, FontWeight.w400, height: 1.45),
      bodyMedium: style(14, FontWeight.w400, height: 1.45),
      bodySmall: style(
        12.5,
        FontWeight.w400,
        height: 1.4,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: style(15, FontWeight.w600, spacing: -0.1),
      labelMedium: style(13, FontWeight.w500, color: scheme.onSurfaceVariant),
      labelSmall: style(
        11,
        FontWeight.w600,
        spacing: 0.8,
        color: scheme.onSurfaceVariant,
      ),
    );
  }

  static ThemeData _build(ColorScheme scheme, AppColors appColors) {
    final text = _textTheme(scheme);
    final isDark = scheme.brightness == Brightness.dark;
    final background = isDark ? AppPalette.ink950 : AppPalette.mist100;

    const pill = StadiumBorder();
    const controlSize = Size(AppSizes.control, AppSizes.control);
    // Campos sin contorno: relleno suave y contorno solo al enfocar o con error.
    const fieldBorder = OutlineInputBorder(
      borderRadius: AppRadius.lgAll,
      borderSide: BorderSide(color: AppPalette.transparent),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: text,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      // Sin ondas de Material: la retroalimentación es la escala al presionar
      // (`PressScale`) y un resaltado suave.
      splashFactory: NoSplash.splashFactory,
      highlightColor: scheme.onSurface.withValues(alpha: AppOpacity.pressed),
      hoverColor: scheme.onSurface.withValues(alpha: AppOpacity.pressed),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [appColors],
      iconTheme: IconThemeData(color: scheme.onSurface, size: AppSizes.iconMd),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: AppPalette.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.lg,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface),
        actionsPadding: const EdgeInsets.only(right: AppSpacing.sm),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.surfaceContainerHigh,
          disabledForegroundColor: scheme.onSurfaceVariant,
          minimumSize: controlSize,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          shape: pill,
          textStyle: text.labelLarge,
          iconSize: AppSizes.iconSm,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: controlSize,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          shape: pill,
          side: BorderSide(
            color: scheme.outlineVariant,
            width: AppSizes.borderThick,
          ),
          textStyle: text.labelLarge,
          iconSize: AppSizes.iconSm,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(
            AppSizes.controlCompact,
            AppSizes.controlCompact,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: pill,
          textStyle: text.labelLarge,
          iconSize: AppSizes.iconSm,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          iconSize: AppSizes.iconMd,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        extendedTextStyle: text.labelLarge,
        shape: pill,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        labelStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: text.labelMedium?.copyWith(color: scheme.onSurface),
        hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
        suffixStyle: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        disabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(
            color: scheme.onSurface,
            width: AppSizes.borderThick,
          ),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(
            color: scheme.error,
            width: AppSizes.borderThin,
          ),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(
            color: scheme.error,
            width: AppSizes.borderThick,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: AppPalette.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurface,
        textColor: scheme.onSurface,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        minLeadingWidth: AppSizes.iconBubble,
        horizontalTitleGap: AppSpacing.md,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: scheme.primary,
        disabledColor: scheme.surfaceContainer,
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge?.copyWith(color: scheme.onPrimary),
        side: BorderSide(color: scheme.outlineVariant),
        shape: pill,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        iconTheme: IconThemeData(
          color: scheme.onSurface,
          size: AppSizes.iconSm,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: AppPalette.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.xxl)),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          0,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // Siempre oscuro, en ambos temas, para que el ícono de estado contraste.
        backgroundColor: isDark ? AppPalette.ink700 : AppPalette.ink900,
        contentTextStyle: text.bodyMedium?.copyWith(color: AppPalette.mist100),
        actionTextColor: appColors.accent,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: AppPalette.transparent,
        indicatorColor: scheme.primary,
        elevation: 0,
        height: AppSizes.dockAction + AppSpacing.xxl,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: AppSizes.iconMd,
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.secondary,
        linearTrackColor: scheme.surfaceContainer,
        circularTrackColor: scheme.surfaceContainer,
        linearMinHeight: AppSizes.progressBar,
        borderRadius: AppRadius.pillAll,
        refreshBackgroundColor: scheme.surface,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.xs)),
        ),
        side: BorderSide(color: scheme.outline, width: AppSizes.borderThick),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : AppPalette.transparent,
        ),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          selectedBackgroundColor: scheme.primary,
          selectedForegroundColor: scheme.onPrimary,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: text.labelLarge,
          minimumSize: const Size(AppSizes.controlCompact, AppSizes.control),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: AppPalette.transparent,
        elevation: 2,
        textStyle: text.bodyLarge,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: AppPalette.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: AppPalette.transparent,
        headerBackgroundColor: appColors.hero,
        headerForegroundColor: appColors.onHero,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.xxl)),
        ),
        todayBorder: BorderSide(color: scheme.secondary),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: AppSizes.borderThin,
        space: AppSpacing.xxl,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: AppRadius.smAll,
        ),
        textStyle: text.labelMedium?.copyWith(color: scheme.onInverseSurface),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.onSurface,
        selectionHandleColor: scheme.secondary,
        selectionColor: scheme.secondaryContainer,
      ),
    );
  }
}
