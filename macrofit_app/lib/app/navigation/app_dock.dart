import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/presentation/theme/app_colors.dart';
import '../../core/presentation/theme/app_tokens.dart';
import '../../core/presentation/theme/lucide_icons.dart';
import '../../core/presentation/theme/theme_context.dart';
import '../../core/presentation/widgets/glass_surface.dart';
import '../../core/presentation/widgets/press_scale.dart';
import '../../features/auth/domain/entities/role.dart';
import '../routes.dart';
import 'tab_transitions.dart';

/// Un acceso de la barra inferior.
class DockItem {
  const DockItem({
    required this.icon,
    required this.label,
    required this.route,
    this.key,
  });

  final IconData icon;
  final String label;

  /// Ruta a la que lleva (una pestaña o la acción principal).
  final String route;

  /// Clave de prueba del botón.
  final Key? key;
}

/// Pestañas y acción principal de cada rol.
abstract final class DockTabs {
  static const user = [
    DockItem(
      key: Key('home_tab'),
      icon: LucideIcons.house,
      label: 'Inicio',
      route: AppRoutes.userHome,
    ),
    DockItem(
      key: Key('meal_history_button'),
      icon: LucideIcons.utensils,
      label: 'Comidas',
      route: AppRoutes.mealHistory,
    ),
    DockItem(
      key: Key('weekly_summary_button'),
      icon: LucideIcons.chartColumn,
      label: 'Semana',
      route: AppRoutes.weeklySummary,
    ),
    DockItem(
      key: Key('weights_button'),
      icon: LucideIcons.weight,
      label: 'Peso',
      route: AppRoutes.weights,
    ),
  ];

  static const userAction = DockItem(
    key: Key('register_meal_button'),
    icon: LucideIcons.scan,
    label: 'Registrar comida',
    route: AppRoutes.mealPhoto,
  );

  static const coach = [
    DockItem(
      key: Key('home_tab'),
      icon: LucideIcons.house,
      label: 'Inicio',
      route: AppRoutes.coachHome,
    ),
    DockItem(
      key: Key('clients_button'),
      icon: LucideIcons.users,
      label: 'Clientes',
      route: AppRoutes.coachClients,
    ),
    DockItem(
      key: Key('routines_button'),
      icon: LucideIcons.dumbbell,
      label: 'Rutinas',
      route: AppRoutes.coachRoutines,
    ),
  ];

  static const coachAction = DockItem(
    key: Key('invite_code_button'),
    icon: LucideIcons.qrCode,
    label: 'Mi código de invitación',
    route: AppRoutes.coachInviteCode,
  );

  /// Pantallas de captura o edición: la barra se oculta para no distraer ni
  /// permitir salir a media tarea.
  static const _focused = {
    AppRoutes.mealPhoto,
    AppRoutes.mealEstimate,
    AppRoutes.mealForm,
    AppRoutes.coachRoutineNew,
    AppRoutes.coachExercisePicker,
  };

  /// Pestaña de la ruta [location], o `null` si no es una pestaña.
  static int? tabOf(List<DockItem> tabs, String location) {
    for (var index = tabs.length - 1; index > 0; index--) {
      final route = tabs[index].route;
      if (location == route || location.startsWith('$route/')) return index;
    }
    return location == tabs.first.route ? 0 : null;
  }

  /// La barra se muestra en todas las pantallas del rol salvo las de captura.
  static bool showsDock(String location) {
    if (_focused.contains(location)) return false;
    if (location.startsWith('${AppRoutes.coachRoutines}/')) return false;
    return location == AppRoutes.userHome ||
        location.startsWith('${AppRoutes.userHome}/') ||
        AppRoutes.isCoachRoute(location);
  }
}

/// Barra inferior persistente de vidrio líquido (TEC-17). La monta `AppShell`
/// sobre el navegador de la app, así que no se mueve mientras las pantallas se
/// deslizan debajo al cambiar de pestaña.
///
/// Una pestaña abre su pantalla con `go` (el inicio queda debajo y atrás regresa
/// a él); la acción principal la abre con `push`.
class AppDock extends StatefulWidget {
  const AppDock({
    required this.router,
    required this.role,
    required this.location,
    required this.visible,
    super.key,
  });

  final GoRouter router;

  /// Rol de la sesión; `null` sin sesión (no se dibuja nada).
  final Role? role;
  final String location;
  final bool visible;

  /// Alto que ocupa la barra (sin el área segura), para dejar espacio al
  /// contenido.
  static const double clearance =
      AppSizes.dockHeight + AppSpacing.md + AppSpacing.sm;

  @override
  State<AppDock> createState() => _AppDockState();
}

class _AppDockState extends State<AppDock> {
  int? _pressed;

  void _press(int? index) {
    if (index == _pressed) return;
    setState(() => _pressed = index);
  }

  void _openTab(List<DockItem> tabs, int index, int? current) {
    if (index == current) return;
    context.read<TabTransitions>().prepare(index - (current ?? 0));
    widget.router.go(tabs[index].route);
  }

  void _openAction(DockItem action) {
    context.read<TabTransitions>().prepare(0);
    widget.router.push(action.route);
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final tabs = role == Role.coach ? DockTabs.coach : DockTabs.user;
    final action = role == Role.coach
        ? DockTabs.coachAction
        : DockTabs.userAction;
    final current = DockTabs.tabOf(tabs, widget.location);

    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedSlide(
        offset: widget.visible ? Offset.zero : const Offset(0, 1.4),
        duration: AppDurations.normal,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: widget.visible ? 1 : 0,
          duration: AppDurations.normal,
          child: role == null
              ? const SizedBox.shrink()
              : _DockBar(
                  tabs: tabs,
                  action: action,
                  current: current,
                  pressed: _pressed,
                  onPressedChanged: _press,
                  onTab: (index) => _openTab(tabs, index, current),
                  onAction: () => _openAction(action),
                ),
        ),
      ),
    );
  }
}

class _DockBar extends StatelessWidget {
  const _DockBar({
    required this.tabs,
    required this.action,
    required this.current,
    required this.pressed,
    required this.onPressedChanged,
    required this.onTab,
    required this.onAction,
  });

  final List<DockItem> tabs;
  final DockItem action;
  final int? current;
  final int? pressed;
  final ValueChanged<int?> onPressedChanged;
  final ValueChanged<int> onTab;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final lensIndex = pressed ?? current;
    final x = lensIndex == null || tabs.length == 1
        ? 0.0
        : -1 + 2 * lensIndex / (tabs.length - 1);

    // La barra vive fuera de las pantallas: lleva su propio Material para la
    // tinta de los toques.
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: GlassSurface(
                  child: SizedBox(
                    height: AppSizes.dockHeight,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Stack(
                        children: [
                          // Lente: se desliza con un rebote "líquido".
                          AnimatedAlign(
                            alignment: Alignment(x, 0),
                            duration: AppDurations.lens,
                            curve: Curves.easeOutBack,
                            child: FractionallySizedBox(
                              widthFactor: 1 / tabs.length,
                              heightFactor: 1,
                              child: AnimatedOpacity(
                                opacity: lensIndex == null ? 0 : 1,
                                duration: AppDurations.normal,
                                child: AnimatedScale(
                                  scale: pressed == null
                                      ? 1
                                      : AppGlass.lensPressedScale,
                                  duration: AppDurations.normal,
                                  curve: Curves.easeOutBack,
                                  child: const _Lens(),
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              for (final (index, item) in tabs.indexed)
                                Expanded(
                                  child: _DockButton(
                                    item: item,
                                    selected: index == current,
                                    highlighted: index == lensIndex,
                                    onTap: () => onTab(index),
                                    onPressedChanged: (isPressed) =>
                                        onPressedChanged(
                                          isPressed ? index : null,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _ActionButton(item: action, onTap: onAction),
            ],
          ),
        ),
      ),
    );
  }
}

class _Lens extends StatelessWidget {
  const _Lens();

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.pillAll,
        color: isDark
            ? AppPalette.white.withValues(alpha: AppOpacity.glass)
            : AppPalette.white.withValues(alpha: AppOpacity.muted),
        border: Border.all(
          color: AppPalette.white.withValues(
            alpha: isDark ? AppOpacity.glass : AppOpacity.muted,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.shadow.withValues(alpha: AppOpacity.shadow),
            blurRadius: AppSpacing.md,
            offset: const Offset(0, AppSpacing.xxs),
          ),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.item,
    required this.selected,
    required this.highlighted,
    required this.onTap,
    required this.onPressedChanged,
  });

  final DockItem item;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;
  final ValueChanged<bool> onPressedChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = highlighted
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: AppOpacity.dockLabel);
    return Semantics(
      button: true,
      selected: selected,
      child: Listener(
        onPointerDown: (_) => onPressedChanged(true),
        onPointerUp: (_) => onPressedChanged(false),
        onPointerCancel: (_) => onPressedChanged(false),
        child: InkWell(
          key: item.key,
          onTap: withHaptic(onTap, selection: true),
          customBorder: const StadiumBorder(),
          splashColor: AppPalette.transparent,
          highlightColor: AppPalette.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: AppDurations.normal,
                child: Icon(
                  item.icon,
                  key: ValueKey(highlighted),
                  color: color,
                  size: AppSizes.dockIcon,
                ),
              ),
              AnimatedDefaultTextStyle(
                duration: AppDurations.normal,
                style: context.text.labelSmall!.copyWith(
                  letterSpacing: 0,
                  color: color,
                  fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón circular de la acción principal: el mismo vidrio gris de la barra.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.item, required this.onTap});

  final DockItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Sin Tooltip: la barra está fuera del Overlay del navegador; la etiqueta
    // llega al lector de pantalla por Semantics.
    return Semantics(
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: PressScale(
        child: GlassSurface(
          borderRadius: AppRadius.pillAll,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: item.key,
              customBorder: const CircleBorder(),
              onTap: withHaptic(onTap),
              child: SizedBox.square(
                dimension: AppSizes.dockAction,
                child: Icon(
                  item.icon,
                  color: context.colors.onSurface,
                  size: AppSizes.iconMd,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
