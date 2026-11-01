import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/validators/routine_validator.dart';
import '../widgets/routine_texts.dart';
import 'routine_builder_view_model.dart';

/// HU-18 — constructor de rutinas: nombre, ejercicios del catálogo con series,
/// repeticiones y descanso, quitar y reordenar (arrastrando el asa) y **Guardar**
/// (CU-04 pasos 2 a 4). Salir con cambios sin guardar pide confirmación.
class RoutineBuilderView extends StatelessWidget {
  const RoutineBuilderView({super.key});

  Future<void> _addExercises(
    BuildContext context,
    RoutineBuilderViewModel viewModel,
  ) async {
    final picked = await context.push<List<Exercise>>(
      AppRoutes.coachExercisePicker,
    );
    if (picked != null) viewModel.addExercises(picked);
  }

  Future<void> _submit(
    BuildContext context,
    RoutineBuilderViewModel viewModel,
  ) async {
    FocusScope.of(context).unfocus();
    final saved = await viewModel.submit();
    if (!saved || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          viewModel.isEditing ? 'Rutina actualizada' : 'Rutina creada',
        ),
      ),
    );
    context.pop(true);
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content: const Text('Los cambios de esta rutina no se guardarán.'),
        actions: [
          TextButton(
            key: const Key('routine_discard_cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            key: const Key('routine_discard_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if ((discard ?? false) && context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RoutineBuilderViewModel>();
    final entries = viewModel.entries;

    return PopScope<Object?>(
      canPop: !viewModel.hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(viewModel.isEditing ? 'Editar rutina' : 'Nueva rutina'),
        ),
        body: SafeArea(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            buildDefaultDragHandles: false,
            itemCount: entries.length,
            onReorderItem: viewModel.move,
            header: _Header(viewModel: viewModel),
            footer: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (viewModel.exercisesError case final message?) ...[
                    Text(
                      message,
                      key: const Key('routine_exercises_error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    key: const Key('routine_add_exercises'),
                    onPressed: viewModel.canAddExercises
                        ? () => _addExercises(context, viewModel)
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar ejercicios'),
                  ),
                  if (!viewModel.canAddExercises)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Máximo ${RoutineValidator.maxExercises} ejercicios '
                        'por rutina.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            itemBuilder: (context, index) => _EntryCard(
              key: ValueKey(entries[index].key),
              index: index,
              entry: entries[index],
              viewModel: viewModel,
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              key: const Key('routine_submit'),
              onPressed: viewModel.isSubmitting
                  ? null
                  : () => _submit(context, viewModel),
              child: viewModel.isSubmitting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.viewModel});

  final RoutineBuilderViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (viewModel.generalError case final message?) ...[
          ErrorBanner(key: const Key('routine_error'), message: message),
          const SizedBox(height: 16),
        ],
        TextFormField(
          key: const Key('routine_name'),
          initialValue: viewModel.name,
          onChanged: viewModel.setName,
          textCapitalization: TextCapitalization.sentences,
          maxLength: RoutineValidator.nameMaxChars,
          decoration: InputDecoration(
            labelText: 'Nombre de la rutina',
            hintText: 'Ej. Torso A',
            errorText: viewModel.nameError,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Text('Ejercicios', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          viewModel.entries.isEmpty
              ? 'Agrega ejercicios del catálogo.'
              : 'Arrastra el asa para cambiar el orden.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.index,
    required this.entry,
    required this.viewModel,
    super.key,
  });

  final int index;
  final RoutineEntry entry;
  final RoutineBuilderViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final generalError = viewModel.entryGeneralError(index);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.drag_handle,
                      key: Key('routine_entry_handle_${entry.key}'),
                      semanticLabel: 'Mover',
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}. ${entry.name}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(muscleGroupLabel(entry.muscleGroup)),
                    ],
                  ),
                ),
                IconButton(
                  key: Key('routine_entry_remove_${entry.key}'),
                  tooltip: 'Quitar ejercicio',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => viewModel.remove(index),
                ),
              ],
            ),
            if (generalError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  generalError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _IntField(
                      fieldKey: Key('routine_entry_sets_${entry.key}'),
                      label: 'Series',
                      initialValue: entry.sets,
                      error: viewModel.entryError(
                        index,
                        RoutineValidator.setsField,
                      ),
                      onChanged: (value) => viewModel.setSets(index, value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _IntField(
                      fieldKey: Key('routine_entry_reps_${entry.key}'),
                      label: 'Repeticiones',
                      initialValue: entry.reps,
                      error: viewModel.entryError(
                        index,
                        RoutineValidator.repsField,
                      ),
                      onChanged: (value) => viewModel.setReps(index, value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _IntField(
                      fieldKey: Key('routine_entry_rest_${entry.key}'),
                      label: 'Descanso',
                      suffix: 's',
                      initialValue: entry.restSeconds,
                      error: viewModel.entryError(
                        index,
                        RoutineValidator.restSecondsField,
                      ),
                      onChanged: (value) =>
                          viewModel.setRestSeconds(index, value),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntField extends StatelessWidget {
  const _IntField({
    required this.fieldKey,
    required this.label,
    required this.initialValue,
    required this.error,
    required this.onChanged,
    this.suffix,
  });

  final Key fieldKey;
  final String label;
  final String initialValue;
  final String? error;
  final ValueChanged<String> onChanged;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: fieldKey,
      initialValue: initialValue,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction: TextInputAction.next,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        errorText: error,
        errorMaxLines: 3,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
