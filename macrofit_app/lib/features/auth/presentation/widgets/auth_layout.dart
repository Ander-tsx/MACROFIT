import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/macro_rings.dart';

/// Estructura de la entrada a la app: encabezado con la marca y los anillos de
/// MacroFit llenándose, y una hoja con el formulario. Se desplaza completa
/// cuando aparece el teclado.
class AuthLayout extends StatelessWidget {
  const AuthLayout({required this.tagline, required this.child, super.key});

  final String tagline;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            context.appColors.glow,
            context.theme.scaffoldBackgroundColor,
          ],
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.xxl,
                  AppSpacing.xxl,
                  AppSpacing.xxl,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MacroFit', style: text.headlineLarge),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            tagline,
                            style: text.bodyLarge?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    // Ilustración: los anillos de la app llenándose.
                    const MacroRings(
                      calories: 0.82,
                      protein: 0.64,
                      fat: 0.46,
                      size: AppSizes.ringLarge,
                      strokeWidth: AppSizes.ringStroke,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadius.sheetTop,
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    AppSpacing.xxxl,
                    AppSpacing.xxl,
                    AppSpacing.xxl,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppSizes.maxContentWidth,
                      ),
                      child: FadeSlideIn(child: child),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
