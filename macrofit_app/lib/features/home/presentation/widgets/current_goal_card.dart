import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/error_banner.dart';
import '../../../goals/domain/entities/nutritional_goal.dart';

/// Origen de la meta (RN-06): `Calculada` o `Definida por tu coach`.
String goalSourceLabel(GoalSource source) => switch (source) {
  GoalSource.system => 'Calculada',
  GoalSource.coach => 'Definida por tu coach',
};

/// HU-26 — meta vigente del usuario: calorías, proteína, grasa y su origen.
class CurrentGoalCard extends StatelessWidget {
  const CurrentGoalCard({
    required this.goal,
    required this.isLoading,
    required this.hasNoGoal,
    required this.error,
    required this.onRetry,
    super.key,
  });

  final NutritionalGoal? goal;
  final bool isLoading;
  final bool hasNoGoal;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tu meta diaria', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ..._content(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    final goal = this.goal;
    final retry = OutlinedButton(
      key: const Key('home_goal_retry'),
      onPressed: onRetry,
      child: const Text('Reintentar'),
    );

    if (goal == null) {
      if (isLoading) {
        return const [Center(child: CircularProgressIndicator())];
      }
      if (error case final message?) {
        return [
          ErrorBanner(message: message),
          const SizedBox(height: 12),
          retry,
        ];
      }
      if (hasNoGoal) {
        return const [
          Text(
            'Todavía no tienes una meta. Completa tu perfil o pide a tu '
            'coach que te asigne una.',
            key: Key('home_goal_empty'),
          ),
        ];
      }
      return const [];
    }

    return [
      Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          _GoalValue(
            key: const Key('home_goal_calories'),
            label: 'Calorías',
            value: '${goal.calories} kcal',
          ),
          _GoalValue(
            key: const Key('home_goal_protein'),
            label: 'Proteína',
            value: '${goal.proteinG} g',
          ),
          _GoalValue(
            key: const Key('home_goal_fat'),
            label: 'Grasa',
            value: '${goal.fatG} g',
          ),
        ],
      ),
      const SizedBox(height: 12),
      Chip(
        key: const Key('home_goal_source'),
        avatar: Icon(
          goal.source == GoalSource.coach ? Icons.sports : Icons.calculate,
          size: 18,
        ),
        label: Text(goalSourceLabel(goal.source)),
      ),
      // Falló una recarga: se conserva la última meta y se avisa.
      if (error case final message?) ...[
        const SizedBox(height: 12),
        ErrorBanner(message: message),
        const SizedBox(height: 12),
        retry,
      ],
    ];
  }
}

class _GoalValue extends StatelessWidget {
  const _GoalValue({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        Text(value, style: theme.textTheme.titleLarge),
      ],
    );
  }
}
