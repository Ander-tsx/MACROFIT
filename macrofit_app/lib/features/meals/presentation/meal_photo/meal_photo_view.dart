import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/widgets/error_banner.dart';
import '../../domain/entities/meal_photo.dart';
import 'meal_photo_view_model.dart';

/// HU-06 — "Registrar comida": tomar o elegir la foto, ver la vista previa y subirla.
class MealPhotoView extends StatelessWidget {
  const MealPhotoView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MealPhotoViewModel>();
    final photo = viewModel.photo;

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar comida')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _Preview(photo: photo),
            const SizedBox(height: 16),
            if (viewModel.error case final message?) ...[
              ErrorBanner(key: const Key('meal_photo_error'), message: message),
              const SizedBox(height: 16),
            ],
            if (viewModel.uploaded != null)
              const _UploadedMessage()
            else ...[
              if (photo != null) ...[
                FilledButton.icon(
                  key: const Key('meal_photo_upload'),
                  onPressed: viewModel.isBusy ? null : viewModel.upload,
                  icon: viewModel.isUploading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    viewModel.isUploading ? 'Subiendo foto…' : 'Usar esta foto',
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Cambiar foto',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
              ],
              _SourceButtons(viewModel: viewModel),
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
    final colors = Theme.of(context).colorScheme;
    final photo = this.photo;
    return SizedBox(
      height: 280,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: photo == null
            ? ColoredBox(
                color: colors.surfaceContainerHighest,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.restaurant,
                      size: 64,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Toma una foto de tu comida o elige una de tu galería.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              )
            : Image.memory(
                photo.bytes,
                key: const Key('meal_photo_preview'),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                semanticLabel: 'Vista previa de la foto de tu comida',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          key: const Key('meal_photo_camera'),
          onPressed: enabled ? () => viewModel.pick(PhotoSource.camera) : null,
          icon: const Icon(Icons.photo_camera),
          label: const Text('Tomar foto'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('meal_photo_gallery'),
          onPressed: enabled ? () => viewModel.pick(PhotoSource.gallery) : null,
          icon: const Icon(Icons.photo_library),
          label: const Text('Elegir de la galería'),
        ),
      ],
    );
  }
}

class _UploadedMessage extends StatelessWidget {
  const _UploadedMessage();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('meal_photo_uploaded'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: colors.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Foto subida. En el siguiente paso verás la estimación nutricional.',
              style: TextStyle(color: colors.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
