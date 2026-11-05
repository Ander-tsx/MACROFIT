import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/app_colors.dart';
import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/press_scale.dart';

/// Un acceso de la barra inferior de las pantallas principales.
class DockItem {
  const DockItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.key,
    this.selected = false,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Clave de prueba del botón.
  final Key? key;

  /// Pantalla actual.
  final bool selected;

  /// Acción principal: círculo lima destacado.
  final bool primary;
}

/// Barra inferior flotante de las pantallas principales (guía visual, "Barra
/// inferior"): píldora oscura sobre el contenido. Los accesos abren pantallas
/// con `push`; no cambia las rutas.
class HomeDock extends StatelessWidget {
  const HomeDock({required this.items, super.key});

  final List<DockItem> items;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.md,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: app.hero,
            borderRadius: AppRadius.pillAll,
            boxShadow: AppShadows.floating(context),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                for (final item in items)
                  Expanded(
                    child: item.primary
                        ? _PrimaryDockButton(item: item)
                        : _DockButton(item: item),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({required this.item});

  final DockItem item;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final color = item.selected ? app.onHero : app.onHeroMuted;
    return Semantics(
      button: true,
      selected: item.selected,
      child: PressScale(
        child: InkWell(
          key: item.key,
          onTap: withHaptic(item.onTap, selection: true),
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: AppSizes.dockAction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, color: color, size: AppSizes.iconMd),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(color: color),
                ),
                const SizedBox(height: AppSpacing.xxs),
                // Punto que marca la pantalla actual.
                AnimatedContainer(
                  duration: AppDurations.normal,
                  curve: Curves.easeOutCubic,
                  width: item.selected ? AppSpacing.md : 0,
                  height: AppSpacing.xs,
                  decoration: BoxDecoration(
                    color: app.accent,
                    borderRadius: AppRadius.pillAll,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryDockButton extends StatelessWidget {
  const _PrimaryDockButton({required this.item});

  final DockItem item;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Align(
      heightFactor: 1,
      child: Tooltip(
        message: item.label,
        child: Semantics(
          button: true,
          label: item.label,
          excludeSemantics: true,
          child: PressScale(
            child: Material(
              color: app.accent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: item.key,
                onTap: withHaptic(item.onTap),
                child: SizedBox.square(
                  dimension: AppSizes.dockAction,
                  child: Icon(
                    item.icon,
                    color: app.onAccent,
                    size: AppSizes.iconLg,
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
