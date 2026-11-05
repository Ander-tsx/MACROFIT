import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_context.dart';

/// Avatar circular con la inicial del nombre. El color sale del nombre, así que
/// la misma persona tiene siempre el mismo color.
class AppAvatar extends StatelessWidget {
  const AppAvatar({required this.name, this.size = AppSizes.avatar, super.key});

  final String name;
  final double size;

  /// Inicial en mayúscula, o `?` si no hay nombre.
  static String initialOf(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final pairs = [
      (app.successContainer, app.onSuccessContainer),
      (app.infoContainer, app.onInfoContainer),
      (app.warningContainer, app.onWarningContainer),
    ];
    final (background, foreground) =
        pairs[name.trim().hashCode.abs() % pairs.length];
    final text = size >= AppSizes.avatarLarge
        ? context.text.headlineMedium
        : context.text.titleMedium;

    // Aro con los tres colores de los macros alrededor de la inicial.
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(AppSpacing.xxs),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [app.calories, app.protein, app.fat, app.calories],
          ),
        ),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            border: Border.all(
              color: context.theme.scaffoldBackgroundColor,
              width: AppSpacing.xxs,
            ),
          ),
          child: Text(
            initialOf(name),
            style: text?.copyWith(color: foreground),
          ),
        ),
      ),
    );
  }
}
