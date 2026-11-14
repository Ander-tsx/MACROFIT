import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Llama a [onReturn] cada vez que la ruta [path] vuelve a quedar visible después de
/// haber abierto otra encima, venga de un `pop` o de un `go` (p. ej. guardar una comida
/// abre "Mis comidas" con `go` y atrás regresa al inicio, HU-09).
class RefreshOnReturn extends StatefulWidget {
  const RefreshOnReturn({
    required this.path,
    required this.onReturn,
    required this.child,
    super.key,
  });

  final String path;
  final Future<void> Function() onReturn;
  final Widget child;

  @override
  State<RefreshOnReturn> createState() => _RefreshOnReturnState();
}

class _RefreshOnReturnState extends State<RefreshOnReturn> {
  GoRouterDelegate? _delegate;
  bool _wasAway = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final delegate = GoRouter.of(context).routerDelegate;
    if (delegate == _delegate) return;
    _delegate?.removeListener(_onRouteChanged);
    _delegate = delegate..addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    _delegate?.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    // Con `push` la ruta de la configuración no cambia: se mira la pantalla de arriba.
    final configuration = _delegate?.currentConfiguration;
    if (configuration == null || configuration.isEmpty) return;
    final visible = configuration.last.matchedLocation == widget.path;
    if (!visible) {
      _wasAway = true;
    } else if (_wasAway) {
      _wasAway = false;
      widget.onReturn();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
