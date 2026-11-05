/// Datos de las gráficas compartidas. Son tipos de presentación, sin reglas de
/// negocio: cada pantalla convierte sus entidades a estos valores (HU-22 para el
/// usuario y HU-23 para el coach usan las mismas gráficas).
library;

/// Un punto de una serie en el tiempo.
class ChartPoint {
  const ChartPoint({required this.label, required this.value});

  /// Etiqueta corta del eje horizontal (`4 nov`).
  final String label;
  final double value;
}

/// Una barra con su meta.
class TargetBar {
  const TargetBar({
    required this.label,
    required this.value,
    this.target,
    this.met = false,
    this.semanticLabel,
  });

  /// Etiqueta corta del eje horizontal (`lun`, `4`).
  final String label;
  final double value;

  /// Meta de esa barra; `null` si no hay.
  final double? target;

  /// La barra cumplió su meta: se dibuja con el color pleno.
  final bool met;

  /// Descripción para el lector de pantalla.
  final String? semanticLabel;
}

/// Una fila de avance «valor de total».
class RatioItem {
  const RatioItem({
    required this.label,
    required this.value,
    required this.total,
  });

  final String label;
  final int value;
  final int total;
}
