<<<<<<< HEAD
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../domain/entities/meal_estimate.dart';
import '../widgets/meal_texts.dart';
=======
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/widgets/error_banner.dart';
import '../../domain/entities/meal_estimate.dart';
>>>>>>> origin/develop
import 'meal_estimate_view_model.dart';

/// HU-07 — "Estimación": carga, alimentos identificados y totales, o las
/// opciones ante un error (reintentar o capturar a mano).
class MealEstimateView extends StatelessWidget {
  const MealEstimateView({super.key});

<<<<<<< HEAD
  /// HU-08: "Continuar" abre el formulario precargado con la estimación y
  /// "Capturar a mano" lo abre vacío (con la foto ya subida).
  void _openForm(BuildContext context, MealEstimateViewModel viewModel) {
    unawaited(context.push(AppRoutes.mealForm, extra: viewModel.formDraft));
=======
  // TODO(HU-08-APP): abrir el formulario de corrección con la estimación
  // ("Continuar") o vacío para la captura manual ("Capturar a mano").
  void _openForm(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('La captura de valores llega en el siguiente paso.'),
      ),
    );
>>>>>>> origin/develop
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MealEstimateViewModel>();
    final estimate = viewModel.estimate;

    return Scaffold(
      appBar: AppBar(title: const Text('Estimación')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                viewModel.upload.photo.bytes,
                key: const Key('meal_estimate_photo'),
                height: 180,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                semanticLabel: 'Foto de tu comida',
              ),
            ),
            const SizedBox(height: 24),
            if (viewModel.isLoading)
              const _Loading()
            else if (estimate != null) ...[
              _Result(estimate: estimate),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('meal_estimate_continue'),
<<<<<<< HEAD
                onPressed: () => _openForm(context, viewModel),
=======
                onPressed: () => _openForm(context),
>>>>>>> origin/develop
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continuar'),
              ),
            ] else if (viewModel.error case final message?) ...[
              ErrorBanner(
                key: const Key('meal_estimate_error'),
                message: message,
              ),
              const SizedBox(height: 24),
              if (viewModel.canRetry) ...[
                FilledButton.icon(
                  key: const Key('meal_estimate_retry'),
                  onPressed: viewModel.retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                key: const Key('meal_estimate_manual'),
<<<<<<< HEAD
                onPressed: () => _openForm(context, viewModel),
=======
                onPressed: () => _openForm(context),
>>>>>>> origin/develop
                icon: const Icon(Icons.edit),
                label: const Text('Capturar a mano'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: const Column(
        key: Key('meal_estimate_loading'),
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Estimando calorías, proteína y grasa…',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.estimate});

  final MealEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final totals = estimate.totals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Alimentos identificados', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final (index, food) in estimate.foods.indexed)
          ListTile(
            key: Key('meal_estimate_food_$index'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restaurant),
            title: Text(food.name),
<<<<<<< HEAD
            subtitle: Text(mealValuesText(food.values)),
            trailing: food.grams == null
                ? null
                : Text('${formatAmount(food.grams!)} g'),
=======
            subtitle: Text(_valuesText(food.values)),
            trailing: food.grams == null
                ? null
                : Text('${_amount(food.grams!)} g'),
>>>>>>> origin/develop
          ),
        const SizedBox(height: 16),
        Card(
          key: const Key('meal_estimate_totals'),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _Total(
                  label: 'Calorías',
<<<<<<< HEAD
                  value: '${formatAmount(totals.caloriesKcal)} kcal',
                ),
                _Total(
                  label: 'Proteína',
                  value: '${formatAmount(totals.proteinG)} g',
                ),
                _Total(label: 'Grasa', value: '${formatAmount(totals.fatG)} g'),
=======
                  value: '${_amount(totals.caloriesKcal)} kcal',
                ),
                _Total(
                  label: 'Proteína',
                  value: '${_amount(totals.proteinG)} g',
                ),
                _Total(label: 'Grasa', value: '${_amount(totals.fatG)} g'),
>>>>>>> origin/develop
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          key: const Key('meal_estimate_disclaimer'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 20, color: colors.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                MealEstimateViewModel.disclaimer,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Cada total ocupa un tercio; con letra grande el valor se reduce en vez
    // de juntarse con el siguiente.
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: textTheme.titleLarge),
            ),
            Text(label, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
<<<<<<< HEAD
=======

/// Cantidad con a lo más un decimal: `413`, `42.2`.
String _amount(double value) {
  final text = value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// `413 kcal · P 42.2 g · G 4.9 g`. Usa espacios sin corte (` `) para
/// que una línea nunca termine en `G` y deje `4.9 g` en la siguiente.
String _valuesText(NutritionValues values) =>
    '${_amount(values.caloriesKcal)} kcal · '
    'P ${_amount(values.proteinG)} g · '
    'G ${_amount(values.fatG)} g';
>>>>>>> origin/develop
