import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Cifra que cuenta desde cero hasta [value] al aparecer y anima los cambios.
/// Al terminar muestra exactamente `format(value)`.
class CountUp extends StatelessWidget {
  const CountUp({
    required this.value,
    required this.builder,
    this.duration = AppDurations.rings,
    super.key,
  });

  final double value;

  /// Construye el texto con el valor animado. Al final recibe [value] exacto.
  final Widget Function(BuildContext context, double value) builder;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) =>
          // El último cuadro usa el valor exacto (sin errores de redondeo).
          builder(context, (animated - value).abs() < 1e-6 ? value : animated),
    );
  }
}
