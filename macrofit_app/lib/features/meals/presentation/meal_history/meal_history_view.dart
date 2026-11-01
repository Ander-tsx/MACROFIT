import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/routes.dart';
import '../../../../core/presentation/widgets/error_banner.dart';
import '../../domain/entities/meal.dart';
import '../widgets/meal_texts.dart';
import 'meal_history_view_model.dart';

/// HU-09 — "Mis comidas": registros del día con hora, foto y valores, cambio de
/// día y eliminación con confirmación (RF-08).
class MealHistoryView extends StatelessWidget {
  const MealHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MealHistoryViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mis comidas')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('meal_history_add'),
        onPressed: () => context.push(AppRoutes.mealPhoto),
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Registrar comida'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _DayBar(viewModel: viewModel),
            const Divider(height: 1),
            Expanded(child: _body(context, viewModel)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, MealHistoryViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.error case final message?) {
      return _Message(
        children: [
          ErrorBanner(message: message),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('meal_history_retry'),
            onPressed: viewModel.load,
            child: const Text('Reintentar'),
          ),
        ],
      );
    }
    if (viewModel.isEmptyDay) {
      return _Message(
        children: [
          Icon(
            Icons.no_meals_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay registros este día.',
            key: Key('meal_history_empty'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('meal_history_pick_date'),
            onPressed: () => _pickDate(context, viewModel),
            child: const Text('Elige otra fecha'),
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: viewModel.load,
      child: ListView(
        // Abajo deja espacio para el botón flotante.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (viewModel.deleteError case final message?) ...[
            ErrorBanner(
              key: const Key('meal_history_delete_error'),
              message: message,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Total del día: ${mealValuesText(viewModel.totals)}',
            key: const Key('meal_history_totals'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final meal in viewModel.meals)
            _MealCard(meal: meal, viewModel: viewModel),
        ],
      ),
    );
  }
}

Future<void> _pickDate(
  BuildContext context,
  MealHistoryViewModel viewModel,
) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: viewModel.date,
    firstDate: DateTime(2020),
    lastDate: viewModel.today,
    helpText: 'Elige el día',
  );
  if (picked != null) unawaited(viewModel.selectDate(picked));
}

/// Pide confirmación, elimina y muestra el aviso que deje el ViewModel.
Future<void> _confirmDelete(
  BuildContext context,
  MealHistoryViewModel viewModel,
  Meal meal,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('¿Eliminar este registro?'),
      content: Text(
        'Se eliminará la comida de las ${mealTimeText(meal.eatenAt)} '
        '(${mealValuesText(meal.values)})'
        '${meal.photoId == null ? '' : ' y su foto'}. No se puede deshacer.',
      ),
      actions: [
        TextButton(
          key: const Key('meal_delete_cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('meal_delete_confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  // La tarjeta de [context] desaparece al eliminar o al recargar el día
  // (`MEAL_NOT_FOUND`): el aviso se muestra con el messenger de la pantalla.
  final messenger = ScaffoldMessenger.of(context);
  await viewModel.delete(meal);
  if (viewModel.takeNotice() case final notice?) {
    messenger.showSnackBar(SnackBar(content: Text(notice)));
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({required this.viewModel});

  final MealHistoryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            key: const Key('meal_history_prev'),
            tooltip: 'Día anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: viewModel.previousDay,
          ),
          Expanded(
            child: TextButton.icon(
              key: const Key('meal_history_date'),
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(dayLabel(viewModel.date, now: viewModel.today)),
              onPressed: () => _pickDate(context, viewModel),
            ),
          ),
          IconButton(
            key: const Key('meal_history_next'),
            tooltip: 'Día siguiente',
            icon: const Icon(Icons.chevron_right),
            onPressed: viewModel.canGoForward ? viewModel.nextDay : null,
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal, required this.viewModel});

  final Meal meal;
  final MealHistoryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      key: Key('meal_${meal.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 72,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: switch (meal.photoId) {
                  final photoId? => _MealPhoto(
                    key: Key('meal_${meal.id}_photo'),
                    photo: viewModel.photo(photoId),
                  ),
                  null => _NoPhoto(key: Key('meal_${meal.id}_manual')),
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mealTimeText(meal.eatenAt),
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(mealValuesText(meal.values)),
                  if (meal.photoId == null)
                    Text('Captura manual', style: textTheme.bodySmall),
                ],
              ),
            ),
            IconButton(
              key: Key('meal_${meal.id}_delete'),
              tooltip: 'Eliminar registro',
              icon: const Icon(Icons.delete_outline),
              onPressed: viewModel.deletingId == null
                  ? () => _confirmDelete(context, viewModel, meal)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _MealPhoto extends StatelessWidget {
  const _MealPhoto({required this.photo, super.key});

  final Future<Uint8List> photo;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<Uint8List>(
      future: photo,
      builder: (context, snapshot) {
        if (snapshot.data case final bytes?) {
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            semanticLabel: 'Foto de la comida',
            errorBuilder: (_, _, _) =>
                Icon(Icons.broken_image_outlined, color: colors.outline),
          );
        }
        if (snapshot.hasError) {
          return ColoredBox(
            color: colors.surfaceContainerHighest,
            child: Icon(Icons.broken_image_outlined, color: colors.outline),
          );
        }
        return ColoredBox(
          color: colors.surfaceContainerHighest,
          child: const Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}

class _NoPhoto extends StatelessWidget {
  const _NoPhoto({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Icon(Icons.restaurant_outlined, color: colors.outline),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.children});

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
