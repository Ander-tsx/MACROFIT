import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/theme/app_text.dart';
import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/presentation/widgets/confirm_dialog.dart';
import '../../../../core/presentation/widgets/content_width.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/error_state.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import 'invite_code_view_model.dart';
import '../../../../core/presentation/theme/lucide_icons.dart';
import '../../../../core/presentation/widgets/card_edge_clip.dart';

/// HU-12 — código de invitación del coach con copiar, compartir y regenerar.
class InviteCodeView extends StatelessWidget {
  const InviteCodeView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<InviteCodeViewModel>();

    return Scaffold(
      appBar: const AppHeader(title: 'Mi código de invitación'),
      body: SafeArea(child: _body(context, viewModel)),
    );
  }

  Widget _body(BuildContext context, InviteCodeViewModel viewModel) {
    final code = viewModel.code;
    if (code == null) {
      if (viewModel.loadError case final message?) {
        return ErrorState(
          message: message,
          onRetry: viewModel.isLoading ? null : viewModel.load,
          retryKey: const Key('invite_code_retry'),
        );
      }
      return const LoadingState();
    }

    final text = context.text;
    final colors = context.colors;
    return CardEdgeClip(
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeSlideIn(
                child: SectionCard(
                  child: Column(
                    children: [
                      Text(
                        'Comparte este código con tus clientes para que se vinculen contigo '
                        'desde su app.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      Text('Tu código', style: text.labelLarge),
                      const SizedBox(height: AppSpacing.sm),
                      AnimatedSwitcher(
                        duration: AppDurations.normal,
                        child: SelectableText(
                          code,
                          key: const Key('invite_code_value'),
                          textAlign: TextAlign.center,
                          style: text.displayMedium
                              ?.merge(AppText.numeric)
                              .copyWith(letterSpacing: AppSpacing.sm),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      // Solo existe mientras se regenera: un indicador infinito
                      // invisible seguiría consumiendo cuadros.
                      AnimatedSize(
                        duration: AppDurations.normal,
                        child: viewModel.isRegenerating
                            ? const LinearProgressIndicator(
                                minHeight: AppSizes.progressBarThin,
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (viewModel.regenerateError case final message?) ...[
                        ErrorBanner(message: message),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              key: const Key('invite_code_copy'),
                              label: 'Copiar',
                              icon: LucideIcons.copy,
                              variant: AppButtonVariant.outlined,
                              onPressed: viewModel.canUseCode
                                  ? () => _copy(context, viewModel)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            // Builder: el contexto del botón da el área donde anclar la hoja en iPad.
                            child: Builder(
                              builder: (buttonContext) => PrimaryButton(
                                key: const Key('invite_code_share'),
                                label: 'Compartir',
                                icon: LucideIcons.share2,
                                onPressed: viewModel.canUseCode
                                    ? () => viewModel.share(
                                        origin: _originOf(buttonContext),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              FadeSlideIn(
                index: 2,
                child: SectionCard(
                  title: 'Regenerar código',
                  subtitle:
                      'Si regeneras el código, el anterior deja de funcionar. Tus clientes '
                      'ya vinculados no se ven afectados.',
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PrimaryButton(
                      key: const Key('invite_code_regenerate'),
                      label: 'Regenerar código',
                      icon: LucideIcons.refreshCw,
                      variant: AppButtonVariant.tonal,
                      expand: false,
                      compact: true,
                      onPressed: viewModel.canUseCode
                          ? () => _regenerate(context, viewModel)
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.cardGap),
              const FadeSlideIn(index: 1, child: _HowItWorks()),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(
    BuildContext context,
    InviteCodeViewModel viewModel,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await viewModel.copy()) {
      showAppSnackBar(
        messenger,
        'Código copiado al portapapeles',
        replaceCurrent: true,
      );
    }
  }

  Future<void> _regenerate(
    BuildContext context,
    InviteCodeViewModel viewModel,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final changed = await viewModel.regenerate(
      () => _confirmRegenerate(context, viewModel.code!),
    );
    if (changed) {
      showAppSnackBar(
        messenger,
        'Código nuevo generado. El anterior ya no funciona.',
        replaceCurrent: true,
      );
    }
  }

  Future<bool> _confirmRegenerate(
    BuildContext context,
    String code,
  ) => showConfirmDialog(
    context: context,
    title: 'Regenerar código',
    message:
        'Se generará un código nuevo y el actual ($code) dejará de funcionar. '
        'Quien aún no se haya vinculado necesitará el código nuevo.',
    confirmLabel: 'Regenerar',
    icon: LucideIcons.refreshCw,
    confirmKey: const Key('invite_code_regenerate_confirm'),
    cancelKey: const Key('invite_code_regenerate_cancel'),
  );

  /// Área del botón en coordenadas globales.
  static Rect? _originOf(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

/// Pasos para que un cliente se vincule.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    'Comparte tu código con tu cliente.',
    'Tu cliente lo escribe en «Vincular con coach».',
    'Aparece en «Mis clientes» y ves su progreso.',
  ];

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    return SectionCard(
      title: 'Cómo funciona',
      child: Column(
        children: [
          for (final (index, step) in _steps.indexed) ...[
            if (index > 0) const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Container(
                  width: AppSizes.macroBadge,
                  height: AppSizes.macroBadge,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text('${index + 1}', style: text.titleSmall),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(step, style: text.bodyMedium)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
