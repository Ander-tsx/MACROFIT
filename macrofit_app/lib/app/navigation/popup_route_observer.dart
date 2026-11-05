import 'package:flutter/widgets.dart';

/// Cuenta los diálogos, hojas y selectores abiertos en el navegador principal
/// para ocultar la barra inferior mientras están en pantalla.
class PopupRouteObserver extends NavigatorObserver with ChangeNotifier {
  int _open = 0;

  bool get hasPopup => _open > 0;

  void _update(int delta) {
    _open = (_open + delta).clamp(0, 1 << 20);
    // Se notifica después del cuadro: el navegador puede estar en plena
    // reconstrucción.
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _update(1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _update(-1);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _update(-1);
  }
}
