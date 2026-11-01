import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../domain/entities/routine.dart';
import '../widgets/routine_texts.dart';
import 'routines_list_view_model.dart';

/// HU-18 — «Mis rutinas»: rutinas del coach, crear, editar y eliminar (CU-04 paso 1).
class RoutinesListView extends StatelessWidget {
  const RoutinesListView({super.key});

  Future<void> _openBuilder(
    BuildContext context,
    RoutinesListViewModel viewModel, {
    Routine? routine,
  }) async {
    await (routine == null
        ? context.push(AppRoutes.coachRoutineNew)
        : context.push(AppRoutes.coachRoutineEdit(routine.id), extra: routine));
    // Al regresar se recarga: la rutina pudo crearse o cambiar.
    await viewModel.load();
  }

  Future<void> _delete(
    BuildContext context,
    RoutinesListViewModel viewModel,
    Routine routine,
  ) async {
    final deleted = await viewModel.delete(
      routine,
      () => _confirmDelete(context, routine),
    );
    if (!deleted || !context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Rutina eliminada')));
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RoutinesListViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis rutinas')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('routines_new'),
        onPressed: () => _openBuilder(context, viewModel),
        icon: const Icon(Icons.add),
        label: const Text('Nueva rutina'),
      ),
      body: SafeArea(child: _body(context, viewModel)),
    );
  }

  Widget _body(BuildContext context, RoutinesListViewModel viewModel) {
    if (viewModel.routines.isEmpty) {
      if (viewModel.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (viewModel.error case final message?) {
        return _CenteredMessage(
          children: [
            ErrorBanner(message: message),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('routines_retry'),
              onPressed: viewModel.load,
              child: const Text('Reintentar'),
            ),
          ],
        );
      }
      if (viewModel.hasNoRoutines) {
        return _CenteredMessage(
          children: [
            Icon(
              Icons.fitness_center,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Todavía no tienes rutinas.\n'
              'Crea una con ejercicios del catálogo para tus clientes.',
              key: Key('routines_empty'),
              textAlign: TextAlign.center,
            ),
          ],
        );
      }
    }

    return Column(
      children: [
        if (viewModel.error case final message?)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: ErrorBanner(
              key: const Key('routines_error'),
              message: message,
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: viewModel.load,
            child: ListView.separated(
              // Espacio para que el botón flotante no tape la última rutina.
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: viewModel.routines.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final routine = viewModel.routines[index];
                return _RoutineTile(
                  routine: routine,
                  isDeleting: viewModel.isDeletingRoutine(routine),
                  enabled: !viewModel.isDeleting,
                  onEdit: () =>
                      _openBuilder(context, viewModel, routine: routine),
                  onDelete: () => _delete(context, viewModel, routine),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

Future<bool> _confirmDelete(BuildContext context, Routine routine) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminar rutina'),
      content: Text(
        '¿Eliminar «${routine.name}»? Esta acción no se puede deshacer.',
      ),
      actions: [
        TextButton(
          key: const Key('routine_delete_cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('routine_delete_confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

enum _RoutineAction { edit, delete }

class _RoutineTile extends StatelessWidget {
  const _RoutineTile({
    required this.routine,
    required this.isDeleting,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
  });

  final Routine routine;
  final bool isDeleting;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('routine_${routine.id}'),
      leading: const CircleAvatar(child: Icon(Icons.fitness_center)),
      title: Text(routine.name),
      subtitle: Text(routineSummaryText(routine)),
      enabled: enabled,
      onTap: onEdit,
      trailing: isDeleting
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : PopupMenuButton<_RoutineAction>(
              key: Key('routine_menu_${routine.id}'),
              enabled: enabled,
              tooltip: 'Opciones',
              onSelected: (action) => switch (action) {
                _RoutineAction.edit => onEdit(),
                _RoutineAction.delete => onDelete(),
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  key: Key('routine_menu_edit'),
                  value: _RoutineAction.edit,
                  child: Text('Editar'),
                ),
                PopupMenuItem(
                  key: Key('routine_menu_delete'),
                  value: _RoutineAction.delete,
                  child: Text('Eliminar'),
                ),
              ],
            ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
