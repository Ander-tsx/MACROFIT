import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/domain/entities/auth_state.dart';
import '../../features/auth/domain/entities/role.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import 'app_dock.dart';
import 'popup_route_observer.dart';

/// Envuelve el navegador de la app con la barra inferior persistente
/// ([AppDock]). Mientras la barra se ve, aumenta el margen inferior seguro
/// (`MediaQuery.padding`) para que el contenido, los botones flotantes y los
/// avisos queden por encima de ella.
class AppShell extends StatefulWidget {
  const AppShell({
    required this.router,
    required this.popups,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final PopupRouteObserver popups;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  GoRouterDelegate get _delegate => widget.router.routerDelegate;

  @override
  void initState() {
    super.initState();
    _delegate.addListener(_refresh);
    widget.popups.addListener(_refresh);
  }

  @override
  void dispose() {
    _delegate.removeListener(_refresh);
    widget.popups.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    // El router puede avisar en plena construcción: entonces se espera al
    // siguiente cuadro.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  String get _location {
    final configuration = _delegate.currentConfiguration;
    if (configuration.isEmpty) return '';
    return configuration.last.matchedLocation;
  }

  @override
  Widget build(BuildContext context) {
    final role = switch (context.watch<AuthRepository>().state) {
      Authenticated(:final user) when user.role == Role.coach => Role.coach,
      Authenticated(:final user) when user.profileCompleted => Role.user,
      _ => null,
    };
    final location = _location;
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom > 0;
    final routeHasDock = role != null && DockTabs.showsDock(location);
    final visible = routeHasDock && !widget.popups.hasPopup && !keyboard;

    // El espacio se reserva según la ruta (no cambia al abrir un diálogo), para
    // que el contenido no salte.
    final reserve = routeHasDock ? AppDock.clearance : 0.0;
    final padded = media.copyWith(
      padding: media.padding.copyWith(bottom: media.padding.bottom + reserve),
      viewPadding: media.viewPadding.copyWith(
        bottom: media.viewPadding.bottom + reserve,
      ),
    );

    return Stack(
      children: [
        MediaQuery(data: padded, child: widget.child),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AppDock(
            router: widget.router,
            role: role,
            location: location,
            visible: visible,
          ),
        ),
      ],
    );
  }
}
