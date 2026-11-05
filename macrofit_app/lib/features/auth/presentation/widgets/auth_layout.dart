import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/brand_mark.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';

/// Estructura de la entrada a la app: encabezado oscuro con la marca y una hoja
/// clara con el formulario. Se desplaza completa cuando aparece el teclado.
class AuthLayout extends StatelessWidget {
  const AuthLayout({required this.tagline, required this.child, super.key});

  final String tagline;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final text = context.text;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.xxl,
                AppSpacing.screen,
                AppSpacing.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const BrandMark(size: AppSizes.iconXl),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        'MacroFit',
                        style: text.headlineMedium?.copyWith(color: app.onHero),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    tagline,
                    style: text.bodyLarge?.copyWith(color: app.onHeroMuted),
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
              color: context.colors.surface,
              borderRadius: AppRadius.sheetTop,
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screen,
                  AppSpacing.xxl,
                  AppSpacing.screen,
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
    );
  }
}
