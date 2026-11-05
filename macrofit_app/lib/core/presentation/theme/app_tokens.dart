import 'package:flutter/widgets.dart';

/// Tokens de medida de la guía visual (ver `lib/app/README.md`).
///
/// Es el **único** archivo con números de espaciado, radios, tamaños, duraciones
/// y movimiento. Las vistas y los widgets usan estas constantes; nunca valores
/// sueltos.

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

  /// Margen lateral de las pantallas: las tarjetas casi tocan el borde.
  static const double screen = md;

  /// Separación entre tarjetas apiladas.
  static const double cardGap = md;

  /// Sangría de los divisores de listas con avatar o ícono a la izquierda.
  static const double dividerInset = 76;

  /// Espacio libre al final de una lista para que la barra flotante o el
  /// botón flotante no tapen el último elemento.
  static const double bottomBarClearance = 120;

  static const EdgeInsets screenPadding = EdgeInsets.all(screen);
  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(
    horizontal: screen,
  );

  /// Relleno interior de las tarjetas.
  static const EdgeInsets cardPadding = EdgeInsets.all(xl);
  static const EdgeInsets cardPaddingLarge = EdgeInsets.fromLTRB(
    xxl,
    xxl,
    xxl,
    xxl,
  );
}

/// Radios de las esquinas.
abstract final class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 22;

  /// Tarjetas: esquinas muy redondeadas, como en One UI.
  static const double xl = 30;
  static const double xxl = 36;

  /// Forma de píldora (botones, selector de día, barra inferior).
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(xxl),
  );
}

/// Tamaños fijos de componentes.
abstract final class AppSizes {
  static const double iconXs = 14;
  static const double iconSm = 18;
  static const double iconMd = 24;
  static const double iconLg = 28;
  static const double iconXl = 40;

  /// Alto de botones y campos (área táctil cómoda, ≥ 48).
  static const double control = 56;
  static const double controlCompact = 44;

  /// Círculo de color detrás de un ícono.
  static const double iconBubble = 40;
  static const double iconBubbleLarge = 64;

  /// Cuadro redondeado con ícono de una fila de lista (referencia: "Log meal").
  static const double listTile = 56;

  static const double avatar = 44;
  static const double avatarLarge = 72;

  static const double thumbnail = 72;
  static const double spinner = 20;
  static const double spinnerStroke = 2.5;
  static const double frameStroke = 4;

  static const double progressBar = 10;
  static const double progressBarThin = 6;

  /// Anillo alrededor del ícono de cada macro.
  static const double macroBadge = 36;
  static const double macroBadgeStroke = 3.5;

  /// Anillos concéntricos de calorías, proteína y grasa.
  static const double macroRings = 132;
  static const double macroRingsSmall = 44;
  static const double macroRingsStroke = 11;
  static const double macroRingsStrokeSmall = 4;
  static const double macroRingsGap = 3;

  static const double ring = 64;
  static const double ringLarge = 96;

  /// Círculos de la ilustración de los estados vacíos.
  static const double emptyArt = 144;
  static const double emptyArtMiddle = 106;
  static const double emptyArtInner = 68;
  static const double ringStroke = 8;

  static const double borderThin = 1;
  static const double borderThick = 1.5;

  /// Contorno de los mosaicos de datos (`StatTile`).
  static const double tileBorder = 1.8;

  /// Barra inferior flotante.
  static const double dockHeight = 54;
  static const double dockAction = 54;
  static const double dockIcon = 20;

  /// Selector de periodo ("Hoy").
  static const double periodPill = 52;

  /// Ancho máximo del contenido en pantallas anchas (tableta, web).
  static const double maxContentWidth = 560;

  static const double photoPreview = 340;
  static const double photoHeader = 230;
  static const double photoBanner = 150;
  static const double featureCard = 150;
  static const double featureArt = 132;
  static const double chartHeight = 150;
  static const double chartBar = 10;
  static const double chartGoalMark = 22;
  static const double chartGoalMarkHeight = 3;
  static const double chartDash = 4;
  static const double sparkline = 96;
  static const double macroColumn = 150;
  static const double dot = 8;
  static const double dashGap = 4;
}

/// Vidrio líquido (barra inferior y superficies flotantes).
abstract final class AppGlass {
  /// Desenfoque del contenido que pasa por detrás.
  static const double blur = 22;

  /// Saturación del contenido de fondo (> 1 lo vuelve más vivo, como iOS).
  static const double saturation = 1.7;

  /// Opacidad del tinte en claro y en oscuro.
  static const double tintLight = 0.78;
  static const double tintDark = 0.42;

  /// Brillo especular de la esquina superior.
  static const double highlight = 0.38;

  /// Contorno de luz: más intenso arriba, casi invisible abajo.
  static const double rimTop = 0.7;
  static const double rimBottom = 0.08;

  /// La lente seleccionada crece un poco al presionar.
  static const double lensPressedScale = 1.06;
}

/// Duraciones de las animaciones.
abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 700);
  static const Duration rings = Duration(milliseconds: 1100);
  static const Duration lens = Duration(milliseconds: 520);
}

/// Sombras suaves (solo en el tema claro).
abstract final class AppElevation {
  static const double softBlur = 24;
  static const double softOffset = 6;
  static const double floatingBlur = 30;
  static const double floatingOffset = 10;
}

/// Retroalimentación y entradas animadas.
abstract final class AppMotion {
  /// Escala de un elemento mientras se mantiene presionado.
  static const double pressedScale = 0.97;

  /// Desplazamiento vertical de la entrada de un elemento (px).
  static const double enterOffset = 18;

  /// Retraso entre elementos de una lista al entrar.
  static const Duration stagger = Duration(milliseconds: 60);
  static const Duration enter = Duration(milliseconds: 480);
}

/// Opacidades usadas sobre fotos y superficies.
abstract final class AppOpacity {
  static const double scrim = 0.55;
  static const double glass = 0.16;
  static const double muted = 0.72;
  static const double disabled = 0.38;
  static const double shadow = 0.05;
  static const double shadowDark = 0.4;
  static const double pressed = 0.05;
  static const double hairline = 0.6;
  static const double track = 0.22;
  static const double art = 0.18;

  /// Imagen de fondo de las tarjetas destacadas (muy tenue bajo el color).
  static const double featureImage = 0.32;

  /// Texto de los accesos no activos de la barra inferior.
  static const double dockLabel = 0.86;
  static const double featureTintStrong = 0.92;
  static const double featureTintSoft = 0.62;
}
