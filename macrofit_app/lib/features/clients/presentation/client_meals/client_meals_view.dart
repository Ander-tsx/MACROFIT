import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/presentation/widgets/error_banner.dart';
import '../../domain/entities/client_meal.dart';
import '../widgets/client_meal_texts.dart';
import 'client_meals_view_model.dart';

/// HU-25 — registro diario de comidas de un cliente. Solo lectura (RN-07): no hay
/// opciones para crear, editar ni eliminar registros.
///
/// Si el cliente ya no está vinculado, **Volver a mis clientes** cierra esta pantalla
/// con `true` y el detalle también se cierra para regresar a la lista.
class ClientMealsView extends StatelessWidget {
  const ClientMealsView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ClientMealsViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text('Comidas de ${viewModel.client.name}')),
      body: SafeArea(
        child: viewModel.isUnlinked
            ? _Message(
                children: [
                  const ErrorBanner(
                    message: 'Este cliente ya no está vinculado contigo.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('client_meals_back'),
                    onPressed: () => context.pop(true),
                    child: const Text('Volver a mis clientes'),
                  ),
                ],
              )
            : Column(
                children: [
                  _DayBar(viewModel: viewModel),
                  const Divider(height: 1),
                  Expanded(child: _body(context, viewModel)),
                ],
              ),
      ),
    );
  }

  Widget _body(BuildContext context, ClientMealsViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.error case final message?) {
      return _Message(
        children: [
          ErrorBanner(message: message),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('client_meals_retry'),
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
          const Text('No hay registros este día.', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('client_meals_pick_date'),
            onPressed: () => _pickDate(context, viewModel),
            child: const Text('Elige otra fecha'),
          ),
        ],
      );
    }
    final totals = viewModel.totals;
    return RefreshIndicator(
      onRefresh: viewModel.load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Total del día: ${mealValuesText(calories: totals.calories, proteinG: totals.proteinG, fatG: totals.fatG)}',
            key: const Key('client_meals_totals'),
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
  ClientMealsViewModel viewModel,
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

class _DayBar extends StatelessWidget {
  const _DayBar({required this.viewModel});

  final ClientMealsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            key: const Key('client_meals_prev'),
            tooltip: 'Día anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: viewModel.previousDay,
          ),
          Expanded(
            child: TextButton.icon(
              key: const Key('client_meals_date'),
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(dayLabel(viewModel.date, now: viewModel.today)),
              onPressed: () => _pickDate(context, viewModel),
            ),
          ),
          IconButton(
            key: const Key('client_meals_next'),
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

  final ClientMeal meal;
  final ClientMealsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 72,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: switch (meal.photoUrl) {
                  final url? => _MealPhoto(
                    key: Key('meal_${meal.id}_photo'),
                    photo: viewModel.photo(url),
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
                  Text(
                    mealValuesText(
                      calories: meal.caloriesKcal,
                      proteinG: meal.proteinG,
                      fatG: meal.fatG,
                    ),
                  ),
                  if (meal.photoUrl == null)
                    Text('Captura manual', style: textTheme.bodySmall),
                ],
              ),
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
