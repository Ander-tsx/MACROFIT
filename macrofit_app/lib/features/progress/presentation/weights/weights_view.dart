import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/theme/app_text.dart';
import '../../../../core/presentation/theme/app_tokens.dart';
import '../../../../core/presentation/theme/theme_context.dart';
import '../../../../core/presentation/widgets/app_header.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/presentation/widgets/app_text_field.dart';
import '../../../../core/presentation/widgets/content_width.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../../core/presentation/widgets/error_state.dart';
import '../../../../core/presentation/widgets/fade_slide_in.dart';
import '../../../../core/presentation/widgets/loading_state.dart';
import '../../../../core/presentation/widgets/primary_button.dart';
import '../../../../core/presentation/widgets/section_card.dart';
import '../../domain/entities/weight_entry.dart';
import '../widgets/weight_trend_chart.dart';
import '../widgets/weights_texts.dart';
import 'weights_view_model.dart';
import '../../../../core/presentation/theme/lucide_icons.dart';
import '../../../../core/presentation/widgets/card_edge_clip.dart';

/// HU-21 — formulario de registro e historial de peso.
class WeightsView extends StatelessWidget {
  const WeightsView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WeightsViewModel>();

    return Scaffold(
      appBar: const AppHeader(title: 'Registro de peso'),
      body: SafeArea(
        child: CardEdgeClip(
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeSlideIn(child: _History(viewModel: viewModel)),
                  const SizedBox(height: AppSpacing.cardGap),
                  FadeSlideIn(
                    index: 1,
                    child: SectionCard(
                      title: 'Registrar nuevo peso',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (viewModel.generalError case final message?) ...[
                            ErrorBanner(message: message),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          AppTextField(
                            key: const Key('weight_input'),
                            label: 'Peso (kg)',
                            hint: 'Ej. 75.5',
                            icon: LucideIcons.weight,
                            suffixText: 'kg',
                            errorText: viewModel.fieldError('weight_kg'),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: viewModel.setWeightInput,
                            enabled: !viewModel.isSubmitting,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          PrimaryButton(
                            key: const Key('submit_weight'),
                            label: 'Registrar peso',
                            icon: LucideIcons.plus,
                            isLoading: viewModel.isSubmitting,
                            onPressed: () => _submit(context, viewModel),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, WeightsViewModel viewModel) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await viewModel.registerWeight();
    if (success) showAppSnackBar(messenger, 'Peso registrado correctamente');
  }
}

/// Último peso en grande, tendencia y registros anteriores.
class _History extends StatelessWidget {
  const _History({required this.viewModel});

  final WeightsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final weights = viewModel.weights;
    return SectionCard(
      title: 'Historial de peso',
      child: StateSwitcher(
        stateKey: viewModel.isLoading && weights.isEmpty
            ? 'loading'
            : viewModel.loadError != null
            ? 'error'
            : weights.isEmpty
            ? 'empty'
            : 'data',
        child: _content(context, weights),
      ),
    );
  }

  Widget _content(BuildContext context, List<WeightEntry> weights) {
    if (viewModel.isLoading && weights.isEmpty) {
      return const LoadingState(compact: true);
    }
    if (viewModel.loadError case final message?) {
      return ErrorState(
        compact: true,
        message: message,
        onRetry: viewModel.load,
        retryKey: const Key('weights_retry'),
      );
    }
    if (weights.isEmpty) {
      return const EmptyState(
        compact: true,
        icon: LucideIcons.weight,
        title: 'Aún no tienes registros de peso.',
        message: 'Registra tu peso para ver cómo cambia con el tiempo.',
      );
    }

    final text = context.text;
    final latest = weights.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: '${latest.weightKg}',
            style: text.displayMedium?.merge(AppText.numeric),
            children: [
              TextSpan(
                text: ' kg',
                style: text.titleMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(
          'Último registro: ${weightDateText(latest.recordedAt)}',
          style: text.bodySmall,
        ),
        if (weights.length > 1) ...[
          const SizedBox(height: AppSpacing.lg),
          WeightTrendChart(
            values: [for (final entry in weights.reversed) entry.weightKg],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        for (final (index, entry) in weights.indexed) ...[
          if (index > 0) const Divider(height: AppSpacing.lg),
          _WeightRow(entry: entry, delta: weightDelta(weights, index)),
        ],
      ],
    );
  }
}

/// Un registro del historial: fecha, peso y el cambio contra el anterior.
class _WeightRow extends StatelessWidget {
  const _WeightRow({required this.entry, required this.delta});

  final WeightEntry entry;
  final ({String text, WeightTrend trend})? delta;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final colors = context.colors;
    final app = context.appColors;
    final delta = this.delta;
    return Row(
      children: [
        Expanded(
          child: Text(
            weightDateText(entry.recordedAt),
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
        Text(
          '${entry.weightKg} kg',
          style: text.titleMedium?.merge(AppText.numeric),
        ),
        if (delta != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: switch (delta.trend) {
                WeightTrend.down => app.successContainer,
                WeightTrend.up => app.warningContainer,
                WeightTrend.same => colors.surfaceContainer,
              },
              borderRadius: AppRadius.pillAll,
            ),
            child: Text(
              delta.text,
              style: text.labelMedium
                  ?.merge(AppText.numeric)
                  .copyWith(
                    color: switch (delta.trend) {
                      WeightTrend.down => app.onSuccessContainer,
                      WeightTrend.up => app.onWarningContainer,
                      WeightTrend.same => colors.onSurfaceVariant,
                    },
                  ),
            ),
          ),
        ],
      ],
    );
  }
}
