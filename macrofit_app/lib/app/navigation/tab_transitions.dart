import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/presentation/theme/app_tokens.dart';

/// Dirección del cambio de pestaña desde la barra inferior (TEC-17): la pantalla
/// nueva entra desde la derecha si la pestaña está a la derecha de la actual y
/// desde la izquierda si está a la izquierda, como un carrusel.
///
/// Una instancia por app (la crea `MacroFitApp`); no es un singleton global.
class TabTransitions {
  int _pending = 0;
  int _direction = 0;
  int _serial = 0;

  /// Dirección del último cambio hecho con la barra (-1, 0 o 1).
  int get direction => _direction;

  /// Cuántos cambios de pestaña se han hecho con la barra.
  int get serial => _serial;

  /// La barra la llama justo antes de navegar.
  void prepare(int direction) {
    _pending = direction.sign;
    _direction = direction.sign;
    _serial++;
  }

  /// La pantalla nueva toma la dirección con la que debe entrar (una sola vez).
  int consume() {
    final direction = _pending;
    _pending = 0;
    return direction;
  }
}

/// Página de una pestaña: entra deslizándose de lado cuando se llega desde la
/// barra inferior y con un fundido suave cuando se llega de otra forma.
Page<void> tabPage(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  transitionDuration: AppDurations.page,
  reverseTransitionDuration: AppDurations.page,
  child: child,
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      _TabTransition(animation: animation, child: child),
);

class _TabTransition extends StatefulWidget {
  const _TabTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  State<_TabTransition> createState() => _TabTransitionState();
}

class _TabTransitionState extends State<_TabTransition> {
  late final TabTransitions _transitions;
  late final int _entry;
  late final int _serial;

  @override
  void initState() {
    super.initState();
    // La dirección se toma en cuanto se crea la página.
    _transitions = context.read<TabTransitions>();
    _entry = _transitions.consume();
    _serial = _transitions.serial;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final value = Curves.easeOutCubic.transform(widget.animation.value);
        final leaving = widget.animation.status == AnimationStatus.reverse;
        // Al salir porque se eligió otra pestaña, se va hacia el lado contrario
        // al que se avanza; si no (atrás), deshace su entrada.
        final direction = leaving && _transitions.serial != _serial
            ? -_transitions.direction
            : _entry;
        if (direction == 0) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, AppMotion.enterOffset * (1 - value)),
              child: child,
            ),
          );
        }
        return FractionalTranslation(
          translation: Offset(direction * (1 - value), 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
