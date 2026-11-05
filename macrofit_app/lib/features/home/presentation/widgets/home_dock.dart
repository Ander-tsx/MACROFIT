import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/app_colors.dart';
import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/glass_surface.dart';
import '../../../../core/presentation/widgets/press_scale.dart';

/// Un acceso de la barra inferior de las pantallas principales.
class DockItem {
  const DockItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selectedIcon,
    this.key,
    this.selected = false,
  });

  final IconData icon;

  /// Ícono relleno cuando es la pantalla actual.
  final IconData? selectedIcon;
  final String label;
  final VoidCallback onTap;

  /// Clave de prueba del botón.
  final Key? key;

  /// Pantalla actual.
  final bool selected;
}

/// Barra inferior flotante de vidrio líquido (guía visual, "Barra inferior").
///
/// - Píldora de vidrio con los accesos y una lente que marca la pantalla actual.
/// - Al presionar un acceso, la lente se desliza hacia el dedo con un rebote
///   suave; al soltar vuelve a su lugar mientras se abre la pantalla.
/// - Aparte, un botón circular con la acción principal.
///
/// Los accesos abren pantallas con `push`; no cambia las rutas.
class HomeDock extends StatefulWidget {
  const HomeDock({required this.items, required this.action, super.key});

  final List<DockItem> items;

  /// Acción principal (botón circular de la derecha).
  final DockItem action;

  @override
  State<HomeDock> createState() => _HomeDockState();
}

class _HomeDockState extends State<HomeDock> {
  int? _pressed;

  int get _selected {
    final index = widget.items.indexWhere((item) => item.selected);
    return index < 0 ? 0 : index;
  }

  void _press(int? index) {
    if (index == _pressed) return;
    setState(() => _pressed = index);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final lensIndex = _pressed ?? _selected;
    final x = items.length == 1 ? 0.0 : -1 + 2 * lensIndex / (items.length - 1);

    return SafeArea(
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
                            widthFactor: 1 / items.length,
                            heightFactor: 1,
                            child: AnimatedScale(
                              scale: _pressed == null
                                  ? 1
                                  : AppGlass.lensPressedScale,
                              duration: AppDurations.normal,
                              curve: Curves.easeOutBack,
                              child: const _Lens(),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (final (index, item) in items.indexed)
                              Expanded(
                                child: _DockButton(
                                  item: item,
                                  highlighted: index == lensIndex,
                                  onPressedChanged: (pressed) =>
                                      _press(pressed ? index : null),
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
            _ActionButton(item: widget.action),
          ],
        ),
      ),
    );
  }
}

/// Lente de vidrio más claro bajo el acceso actual.
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
    required this.highlighted,
    required this.onPressedChanged,
  });

  final DockItem item;
  final bool highlighted;
  final ValueChanged<bool> onPressedChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = highlighted
        ? colors.onSurface
        : colors.onSurface.withValues(alpha: AppOpacity.dockLabel);
    return Semantics(
      button: true,
      selected: item.selected,
      child: Listener(
        onPointerDown: (_) => onPressedChanged(true),
        onPointerUp: (_) => onPressedChanged(false),
        onPointerCancel: (_) => onPressedChanged(false),
        child: InkWell(
          key: item.key,
          onTap: withHaptic(item.onTap, selection: true),
          customBorder: const StadiumBorder(),
          splashColor: AppPalette.transparent,
          highlightColor: AppPalette.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: AppDurations.normal,
                child: Icon(
                  highlighted ? (item.selectedIcon ?? item.icon) : item.icon,
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

/// Botón circular de la acción principal: degradado de marca con brillo de
/// vidrio encima.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.item});

  final DockItem item;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Tooltip(
      message: item.label,
      child: Semantics(
        button: true,
        label: item.label,
        excludeSemantics: true,
        child: PressScale(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: app.accent.withValues(alpha: AppOpacity.track * 2),
                  blurRadius: AppElevation.floatingBlur,
                  offset: const Offset(0, AppElevation.softOffset),
                ),
              ],
            ),
            child: Material(
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [app.accent, app.calories],
                  ),
                ),
                child: InkWell(
                  key: item.key,
                  onTap: withHaptic(item.onTap),
                  child: SizedBox.square(
                    dimension: AppSizes.dockAction,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Brillo especular superior.
                        Positioned(
                          top: AppSpacing.xs,
                          left: AppSpacing.md,
                          right: AppSpacing.md,
                          height: AppSizes.dockAction / 2.4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.pillAll,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppPalette.white.withValues(
                                    alpha: AppGlass.highlight,
                                  ),
                                  AppPalette.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Icon(
                          item.icon,
                          color: app.onAccent,
                          size: AppSizes.iconLg,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
