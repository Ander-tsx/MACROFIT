import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/status_banner.dart';
import '../../../../core/presentation/widgets/surface_card.dart';
import '../../domain/entities/meal.dart';
import '../../domain/entities/meal_photo.dart';
import '../widgets/scan_frame.dart';
import 'meal_photo_view_model.dart';

/// HU-06 — "Registrar comida": tomar o elegir la foto, ver la vista previa y subirla.
class MealPhotoView extends StatelessWidget {
  const MealPhotoView({super.key});

  /// Sube la foto y, si se guardó, abre la estimación (HU-07). `go` reemplaza
  /// esta pantalla: la foto subida ya no se puede cambiar y atrás vuelve al inicio.
  Future<void> _upload(
    BuildContext context,
    MealPhotoViewModel viewModel,
  ) async {
    await viewModel.upload();
    if (!context.mounted) return;
    if (viewModel.result case final upload?) {
      context.go(AppRoutes.mealEstimate, extra: upload);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MealPhotoViewModel>();
    final photo = viewModel.photo;

    return Scaffold(
      appBar: const AppHeader(title: 'Registrar comida'),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            FadeSlideIn(child: _Preview(photo: photo)),
            const SizedBox(height: AppSpacing.xl),
            if (viewModel.error case final message?) ...[
              FadeSlideIn(
                child: ErrorBanner(
                  key: const Key('meal_photo_error'),
                  message: message,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            if (viewModel.uploaded != null)
              const FadeSlideIn(
                child: StatusBanner(
                  key: Key('meal_photo_uploaded'),
                  tone: StatusTone.success,
                  message: 'Foto subida. En el siguiente paso verás la estimación nutricional.',
                ),
              )
            else ...[
              if (photo != null) ...[
                PrimaryButton(
                  key: const Key('meal_photo_upload'),
                  label: viewModel.isUploading
                      ? 'Subiendo foto…'
                      : 'Usar esta foto',
                  icon: Icons.arrow_upward_rounded,
                  isLoading: viewModel.isUploading,
                  onPressed: viewModel.isBusy
                      ? null
                      : () => _upload(context, viewModel),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Cambiar foto',
                  style: context.text.titleSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              FadeSlideIn(
                index: 1,
                child: _SourceButtons(viewModel: viewModel),
              ),
              const SizedBox(height: AppSpacing.md),
              // HU-08: captura manual sin foto (formulario vacío, sin photo_id).
              PrimaryButton(
                key: const Key('meal_photo_manual'),
                label: 'Capturar sin foto',
                icon: Icons.edit_note_rounded,
                variant: AppButtonVariant.ghost,
                onPressed: viewModel.isBusy
                    ? null
                    : () => context.push(
                        AppRoutes.mealForm,
                        extra: const MealDraft(),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.photo});

  final PickedPhoto? photo;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final photo = this.photo;
    return SizedBox(
      height: AppSizes.photoPreview,
      child: ClipRRect(
        borderRadius: AppRadius.xlAll,
        child: AnimatedSwitcher(
          duration: AppDurations.normal,
          child: photo == null
              ? ColoredBox(
                  key: const ValueKey('placeholder'),
                  color: app.hero,
                  child: Stack(
                    children: [
                      ScanFrame(color: app.accent),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.huge),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.restaurant_rounded,
                                size: AppSizes.iconXl,
                                color: app.onHero,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Toma una foto de tu comida o elige una de tu galería.',
                                textAlign: TextAlign.center,
                                style: context.text.bodyMedium?.copyWith(
                                  color: app.onHeroMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Stack(
                  key: ValueKey(photo),
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      photo.bytes,
                      key: const Key('meal_photo_preview'),
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      semanticLabel: 'Vista previa de la foto de tu comida',
                    ),
                    ScanFrame(color: app.onHero),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SourceButtons extends StatelessWidget {
  const _SourceButtons({required this.viewModel});

  final MealPhotoViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final enabled = !viewModel.isBusy;
    return Row(
      children: [
        Expanded(
          child: _SourceTile(
            key: const Key('meal_photo_camera'),
            icon: Icons.photo_camera_rounded,
            label: 'Tomar foto',
            highlighted: true,
            onTap: enabled ? () => viewModel.pick(PhotoSource.camera) : null,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _SourceTile(
            key: const Key('meal_photo_gallery'),
            icon: Icons.photo_library_rounded,
            label: 'Elegir de la galería',
            onTap: enabled ? () => viewModel.pick(PhotoSource.gallery) : null,
          ),
        ),
      ],
    );
  }
}

/// Origen de la foto: tarjeta con ícono y texto.
class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final app = context.appColors;
    final colors = context.colors;
    final foreground = highlighted ? app.onHero : colors.onSurface;
    return AnimatedOpacity(
      opacity: onTap == null ? AppOpacity.disabled : 1,
      duration: AppDurations.fast,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        child: SurfaceCard(
          color: highlighted ? app.hero : null,
          padding: AppSpacing.cardPadding,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppSizes.iconBubble,
                height: AppSizes.iconBubble,
                decoration: BoxDecoration(
                  color: highlighted ? app.accent : colors.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: AppSizes.iconSm,
                  color: highlighted ? app.onAccent : colors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                label,
                maxLines: 2,
                style: context.text.titleSmall?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
