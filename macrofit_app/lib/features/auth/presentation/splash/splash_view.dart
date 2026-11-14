import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/macro_rings.dart';

/// Se muestra mientras se lee la sesión guardada; el router la reemplaza al terminar.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MacroRings(
              calories: 1,
              protein: 0.8,
              fat: 0.6,
              semanticLabel: 'MacroFit',
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('MacroFit', style: context.text.headlineMedium),
            const SizedBox(height: AppSpacing.xxxl),
            SizedBox.square(
              dimension: AppSizes.iconLg,
              child: CircularProgressIndicator(
                strokeWidth: AppSizes.spinnerStroke,
                strokeCap: StrokeCap.round,
                color: app.accent,
                backgroundColor: context.colors.surfaceContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
