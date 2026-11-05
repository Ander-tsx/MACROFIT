import 'package:flutter/widgets.dart';

import '../theme/app_tokens.dart';

/// Entrada suave de un elemento: aparece y sube unos píxeles. Con [index] los
/// elementos de una lista entran escalonados. La animación termina sola (no
/// usa temporizadores), así que no bloquea a `pumpAndSettle` en las pruebas.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({required this.child, this.index = 0, super.key});

  final Widget child;
  final int index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final Duration _delay = AppMotion.stagger * widget.index.clamp(0, 8);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.enter + _delay,
  )..forward();
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      _delay.inMilliseconds / _controller.duration!.inMilliseconds,
      1,
      curve: Curves.easeOutCubic,
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) => Opacity(
        opacity: _progress.value,
        child: Transform.translate(
          offset: Offset(0, AppMotion.enterOffset * (1 - _progress.value)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Transición entre estados de una sección (cargando, vacío, error, datos):
/// el contenido nuevo aparece mientras el anterior se desvanece y el alto se
/// ajusta con suavidad. [stateKey] identifica el estado actual.
class StateSwitcher extends StatelessWidget {
  const StateSwitcher({required this.stateKey, required this.child, super.key});

  final Object stateKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppDurations.normal,
      curve: Curves.easeOutCubic,
      alignment: AlignmentDirectional.topStart,
      child: AnimatedSwitcher(
        duration: AppDurations.normal,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (current, previous) => Stack(
          alignment: AlignmentDirectional.topStart,
          children: [...previous, ?current],
        ),
        child: KeyedSubtree(
          key: ValueKey(stateKey),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}
