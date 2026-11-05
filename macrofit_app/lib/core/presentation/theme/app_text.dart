import 'package:flutter/painting.dart';

/// Ajustes tipográficos que se combinan con el `TextTheme`.
abstract final class AppText {
  /// Cifras de ancho fijo: los números no "bailan" al cambiar o animarse.
  static const numeric = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
