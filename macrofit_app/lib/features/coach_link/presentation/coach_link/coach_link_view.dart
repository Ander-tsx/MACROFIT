import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_avatar.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../core/presentation/widgets/confirm_dialog.dart';
import '../../../../core/presentation/widgets/content_width.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/highlight_card.dart';
import '../../../../core/presentation/widgets/leader_row.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../../domain/entities/coach_link.dart';
import 'coach_link_view_model.dart';
import '../../../../core/presentation/theme/lucide_icons.dart';
import '../../../../core/presentation/theme/app_images.dart';
import '../../../../core/presentation/widgets/card_edge_clip.dart';

/// HU-13 / HU-14 — pantalla para vincularse y desvincularse de un coach.
class CoachLinkView extends StatelessWidget {
  const CoachLinkView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CoachLinkViewModel>();

    return Scaffold(
      appBar: const AppHeader(title: 'Vincular con coach'),
      body: SafeArea(
        child: viewModel.isLoading && viewModel.linkedCoach == null
            ? const LoadingState()
            : CardEdgeClip(
                child: SingleChildScrollView(
                  padding: AppSpacing.screenPadding,
                  child: ContentWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (viewModel.linkedCoach case final coach?)
                          FadeSlideIn(
                            child: _LinkedCoach(
                              coach: coach,
                              isBusy: viewModel.isLoading,
                              onUnlink: () =>
                                  _confirmUnlink(context, viewModel),
                            ),
                          )
                        else ...[
                          const FadeSlideIn(
                            child: HighlightCard(
                              title: 'Entrena con seguimiento',
                              description: 'Ingresa el código de invitación que te proporcionó tu coach para recibir seguimiento.',
                              icon: LucideIcons.link,
                              image: AppImages.coach,
                              tone: HighlightTone.blue,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.cardGap),
                          FadeSlideIn(
                            index: 1,
                            child: SectionCard(
                              title: 'Código de invitación',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AppTextField(
                                    key: const Key('invite_code_input'),
                                    label: 'Código de invitación',
                                    hint: 'Ej. K7P2QX',
                                    icon: LucideIcons.qrCode,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    autocorrect: false,
                                    onChanged: viewModel.updateInviteCode,
                                    enabled: !viewModel.isLoading,
                                  ),
                                  if (viewModel.errorMessage
                                      case final message?) ...[
                                    const SizedBox(height: AppSpacing.md),
                                    FadeSlideIn(
                                      child: ErrorBanner(message: message),
                                    ),
                                  ],
                                  const SizedBox(height: AppSpacing.xl),
                                  PrimaryButton(
                                    key: const Key('submit_coach_link'),
                                    label: 'Vincular coach',
                                    icon: LucideIcons.link,
                                    isLoading: viewModel.isLoading,
                                    onPressed: () =>
                                        _submit(context, viewModel),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    CoachLinkViewModel viewModel,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await viewModel.linkCoach();
    if (success) {
      showAppSnackBar(messenger, '¡Vinculación exitosa con el coach!');
    }
  }

  Future<void> _confirmUnlink(
    BuildContext context,
    CoachLinkViewModel viewModel,
  ) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Desvincularme',
      message: '¿Estás seguro de que deseas desvincularte de tu coach? El coach dejará de ver tus datos.',
      confirmLabel: 'Desvincularme',
      icon: LucideIcons.unlink,
      destructive: true,
    );

    if (confirmed && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final success = await viewModel.unlinkCoach();
      if (success) {
        showAppSnackBar(messenger, 'Te has desvinculado del coach.');
      }
    }
  }
}

/// Coach vinculado: sus datos y la opción de desvincularse (HU-14).
class _LinkedCoach extends StatelessWidget {
  const _LinkedCoach({
    required this.coach,
    required this.isBusy,
    required this.onUnlink,
  });

  final CoachLink coach;
  final bool isBusy;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final app = context.appColors;
    return SectionCard(
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          Stack(
            clipBehavior: Clip.none,
            children: [
              AppAvatar(email: coach.coachEmail, size: AppSizes.avatarLarge),
              Positioned(
                right: -AppSpacing.xs,
                bottom: -AppSpacing.xs,
                child: Icon(
                  LucideIcons.circleCheck,
                  color: app.success,
                  size: AppSizes.iconLg,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('¡Vinculado con éxito!', style: text.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Tu coach ya puede ver tu progreso.',
            style: text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Semantics(
            label: 'Coach: ${coach.coachName}',
            excludeSemantics: true,
            child: LeaderRow(label: 'Coach', value: coach.coachName),
          ),
          Semantics(
            label: 'Correo: ${coach.coachEmail}',
            excludeSemantics: true,
            child: LeaderRow(label: 'Correo', value: coach.coachEmail),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            key: const Key('unlink_coach_button'),
            label: 'Desvincularme',
            icon: LucideIcons.unlink,
            variant: AppButtonVariant.outlined,
            onPressed: isBusy ? null : onUnlink,
          ),
        ],
      ),
    );
  }
}
