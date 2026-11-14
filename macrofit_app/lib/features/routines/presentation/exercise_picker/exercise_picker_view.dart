import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/widgets/error_banner.dart';
import '../../domain/entities/exercise.dart';
import '../widgets/routine_texts.dart';
import 'exercise_picker_view_model.dart';

/// HU-18 — «Agregar ejercicios»: catálogo de `GET /exercises` con filtros por grupo
/// muscular y nivel y selección múltiple (CU-04 paso 3). Regresa con
/// `context.pop(List<Exercise>)`.
class ExercisePickerView extends StatelessWidget {
  const ExercisePickerView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ExercisePickerViewModel>();
    final count = viewModel.selectedCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Agregar ejercicios')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilterRow<MuscleGroup>(
              allKey: const Key('exercise_filter_group_all'),
              allLabel: 'Todos los grupos',
              values: MuscleGroup.values,
              selected: viewModel.muscleGroup,
              label: muscleGroupFilterLabel,
              keyOf: (group) => Key('exercise_filter_group_${group.apiValue}'),
              onSelected: viewModel.setMuscleGroup,
            ),
            _FilterRow<ExerciseLevel>(
              allKey: const Key('exercise_filter_level_all'),
              allLabel: 'Todos los niveles',
              values: ExerciseLevel.values,
              selected: viewModel.level,
              label: levelFilterLabel,
              keyOf: (level) => Key('exercise_filter_level_${level.apiValue}'),
              onSelected: viewModel.setLevel,
            ),
            const Divider(height: 1),
            Expanded(child: _results(context, viewModel)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            key: const Key('exercise_picker_add'),
            onPressed: count == 0
                ? null
                : () => context.pop<List<Exercise>>(viewModel.selected),
            icon: const Icon(Icons.playlist_add),
            label: Text(count == 0 ? 'Agregar' : 'Agregar ($count)'),
          ),
        ),
      ),
    );
  }

  Widget _results(BuildContext context, ExercisePickerViewModel viewModel) {
    if (viewModel.isLoading && viewModel.exercises.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.error case final message?) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ErrorBanner(message: message),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('exercise_picker_retry'),
                onPressed: viewModel.load,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (viewModel.hasNoResults) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No hay ejercicios con estos filtros.',
            key: Key('exercise_picker_empty'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      children: [
        if (viewModel.isLoading) const LinearProgressIndicator(),
        Expanded(
          child: ListView.builder(
            itemCount: viewModel.exercises.length,
            itemBuilder: (context, index) {
              final exercise = viewModel.exercises[index];
              return CheckboxListTile(
                key: Key('exercise_${exercise.id}'),
                value: viewModel.isSelected(exercise),
                onChanged: (_) => viewModel.toggle(exercise),
                title: Text(exercise.name),
                subtitle: Text(exerciseDetailsText(exercise)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterRow<T> extends StatelessWidget {
  const _FilterRow({
    required this.allKey,
    required this.allLabel,
    required this.values,
    required this.selected,
    required this.label,
    required this.keyOf,
    required this.onSelected,
  });

  final Key allKey;
  final String allLabel;
  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final Key Function(T) keyOf;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          ChoiceChip(
            key: allKey,
            label: Text(allLabel),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final value in values) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              key: keyOf(value),
              label: Text(label(value)),
              selected: selected == value,
              onSelected: (_) => onSelected(value),
            ),
          ],
        ],
      ),
    );
  }
}
