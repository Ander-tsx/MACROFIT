import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/app_tokens.dart';

/// Retroalimentación al presionar: el elemento se encoge levemente mientras el
/// dedo está encima. No intercepta gestos; el hijo sigue recibiendo el toque.
class PressScale extends StatefulWidget {
  const PressScale({required this.child, this.enabled = true, super.key});

  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (!widget.enabled || pressed == _pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? AppMotion.pressedScale : 1,
        duration: AppDurations.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Vibración ligera de confirmación al tocar una acción.
abstract final class Haptics {
  static void tap() => HapticFeedback.lightImpact();
  static void select() => HapticFeedback.selectionClick();
}

/// Envuelve un callback para que vibre antes de ejecutarse; `null` sigue
/// deshabilitando el control.
VoidCallback? withHaptic(VoidCallback? callback, {bool selection = false}) {
  if (callback == null) return null;
  return () {
    selection ? Haptics.select() : Haptics.tap();
    callback();
  };
}
