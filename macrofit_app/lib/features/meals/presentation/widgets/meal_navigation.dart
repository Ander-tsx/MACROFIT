import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../domain/entities/meal.dart';

/// HU-09 — después de guardar (desde la estimación o el formulario) se avisa y
/// se abre el historial del día del registro. `go` deja el inicio debajo: atrás
/// regresa a él y no a la foto ni al formulario ya guardados.
void showMealSaved(BuildContext context, Meal meal) {
  ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Comida registrada')));
  context.go(AppRoutes.mealHistory, extra: meal.date);
}
