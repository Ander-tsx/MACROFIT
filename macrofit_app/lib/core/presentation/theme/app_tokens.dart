import 'package:flutter/widgets.dart';

/// Tokens de medida de la guía visual (ver `lib/app/README.md`).
///
/// Es el **único** archivo con números de espaciado, radios, tamaños y duraciones.
/// Las vistas y los widgets usan estas constantes; nunca valores sueltos.

/// Escala de espaciado en múltiplos de 4.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Margen lateral de todas las pantallas.
  static const double screen = xl;

  /// Espacio libre al final de una lista para que la barra inferior o el botón
  /// flotante no tapen el último elemento.
  static const double bottomBarClearance = 112;

  static const EdgeInsets screenPadding = EdgeInsets.all(screen);
  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(
    horizontal: screen,
  );
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(xl);
}

/// Radios de las esquinas.
abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double xxl = 36;

  /// Forma de píldora (botones, chips, buscador).
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  /// Hoja blanca que se monta sobre el encabezado oscuro.
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(xxl),
  );
}

/// Tamaños fijos de componentes.
abstract final class AppSizes {
  static const double iconXs = 14;
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;
  static const double iconXl = 40;

  /// Alto mínimo de botones y campos (área táctil cómoda, ≥ 48).
  static const double control = 56;
  static const double controlCompact = 44;

  /// Círculo de color detrás de un ícono.
  static const double iconBubble = 40;
  static const double iconBubbleLarge = 64;

  static const double avatar = 44;
  static const double avatarLarge = 72;

  static const double thumbnail = 72;
  static const double spinner = 20;
  static const double spinnerStroke = 2.5;
  static const double frameStroke = 4;

  static const double progressBar = 10;
  static const double ringSmall = 44;
  static const double ringStrokeSmall = 6;
  static const double ring = 64;
  static const double ringLarge = 96;
  static const double ringStroke = 8;

  static const double borderThin = 1;
  static const double borderThick = 1.5;

  /// Barra inferior de las pantallas principales.
  static const double dockAction = 56;

  /// Ancho máximo del contenido en pantallas anchas (tableta, web).
  static const double maxContentWidth = 520;

  static const double photoPreview = 320;
  static const double photoHeader = 220;
  static const double photoBanner = 150;
  static const double chartHeight = 160;
  static const double macroColumn = 150;
  static const double chartBar = 18;
  static const double chartGoalMark = 30;
  static const double chartGoalMarkHeight = 3;
  static const double sparkline = 96;
  static const double dot = 8;
}

/// Duraciones de las animaciones.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 600);
}

/// Sombras suaves de las superficies (en lugar de bordes).
abstract final class AppElevation {
  static const double softBlur = 32;
  static const double softOffset = 12;
  static const double floatingBlur = 40;
  static const double floatingOffset = 16;
}

/// Escalas de la retroalimentación al presionar.
abstract final class AppMotion {
  /// Escala de un elemento mientras se mantiene presionado.
  static const double pressedScale = 0.97;

  /// Desplazamiento vertical de la entrada de un elemento (px).
  static const double enterOffset = 16;

  /// Retraso entre elementos de una lista al entrar.
  static const Duration stagger = Duration(milliseconds: 55);
  static const Duration enter = Duration(milliseconds: 420);
}

/// Opacidades usadas sobre fotos y superficies oscuras.
abstract final class AppOpacity {
  static const double scrim = 0.55;
  static const double glass = 0.16;
  static const double muted = 0.72;
  static const double disabled = 0.38;
  static const double shadow = 0.06;
  static const double shadowDark = 0.4;
  static const double pressed = 0.04;
  static const double hairline = 0.6;
}
