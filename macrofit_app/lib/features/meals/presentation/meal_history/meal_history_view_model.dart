import 'dart:typed_data';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/meal.dart';
import '../../domain/entities/meal_estimate.dart';
import '../../domain/repositories/meals_repository.dart';

/// HU-09 — historial de comidas del día del usuario (RF-08): registros del más
/// antiguo al más reciente, cambio de día y eliminación con confirmación.
///
/// Empieza en [initialDate] (el día del registro recién guardado) o en hoy
/// (hora local del teléfono) y no permite días futuros.
class MealHistoryViewModel extends ViewModel {
  MealHistoryViewModel({
    required this._repository,
    DateTime? initialDate,
    this._clock = DateTime.now,
  }) {
    final day = initialDate ?? today;
    _date = DateTime(day.year, day.month, day.day);
  }

  final MealsRepository _repository;
  final DateTime Function() _clock;

  static const deletedMessage = 'Registro eliminado';
  static const alreadyDeletedMessage =
      'Ese registro ya no existía. Actualizamos la lista.';

  late DateTime _date;
  List<Meal> _meals = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;
  String? _deleteError;
  String? _notice;
  String? _deletingId;
  int _request = 0;
  final _photos = <String, Future<Uint8List>>{};

  /// Día consultado (sin hora).
  DateTime get date => _date;
  List<Meal> get meals => _meals;
  bool get isLoading => _isLoading;

  /// No se pudo cargar el día; la vista ofrece reintentar.
  String? get error => _error;

  /// No se pudo eliminar un registro (p. ej. sin conexión); la lista se conserva.
  String? get deleteError => _deleteError;

  /// Aviso para mostrar una sola vez (la vista lo toma con [takeNotice]).
  String? get notice => _notice;

  /// Registro que se está eliminando (su botón se deshabilita).
  String? get deletingId => _deletingId;

  /// El día cargado no tiene registros.
  bool get isEmptyDay => _hasLoaded && _meals.isEmpty;

  bool get canGoForward => _date.isBefore(today);

  DateTime get today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  /// Suma de los valores finales del día.
  NutritionValues get totals {
    var calories = 0.0, protein = 0.0, fat = 0.0;
    for (final meal in _meals) {
      calories += meal.values.caloriesKcal;
      protein += meal.values.proteinG;
      fat += meal.values.fatG;
    }
    return NutritionValues(
      caloriesKcal: calories,
      proteinG: protein,
      fatG: fat,
    );
  }

  /// Entrega el aviso pendiente una sola vez.
  String? takeNotice() {
    final notice = _notice;
    _notice = null;
    return notice;
  }

  /// Carga (o recarga) el día elegido. Si llega la respuesta de un día anterior
  /// después de cambiar de día, se descarta.
  Future<void> load() async {
    final request = ++_request;
    final date = _date;
    _isLoading = true;
    _hasLoaded = false;
    _error = null;
    _deleteError = null;
    _meals = const [];
    notifyListeners();
    try {
      final meals = await _repository.getMeals(date);
      if (request != _request) return;
      _meals = meals;
      _hasLoaded = true;
    } on ApiException catch (error) {
      if (request != _request) return;
      _error = error.message;
    } finally {
      if (request == _request) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Cambia al día de [date] (sin hora); una fecha futura se lleva a hoy.
  Future<void> selectDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    _date = day.isAfter(today) ? today : day;
    return load();
  }

  Future<void> previousDay() =>
      selectDate(DateTime(_date.year, _date.month, _date.day - 1));

  Future<void> nextDay() async {
    if (!canGoForward) return;
    await selectDate(DateTime(_date.year, _date.month, _date.day + 1));
  }

  /// Elimina [meal] (la vista ya pidió confirmación). Si ya no existía
  /// (`MEAL_NOT_FOUND`), recarga el día y lo avisa.
  Future<void> delete(Meal meal) async {
    if (_deletingId != null) return;
    _deletingId = meal.id;
    _deleteError = null;
    notifyListeners();
    try {
      await _repository.deleteMeal(meal.id);
      _meals = [
        for (final other in _meals)
          if (other.id != meal.id) other,
      ];
      _notice = deletedMessage;
    } on ApiException catch (error) {
      if (error.code == ApiErrorCode.mealNotFound) {
        _notice = alreadyDeletedMessage;
        _deletingId = null;
        await load();
        return;
      }
      _deleteError = error.message;
    } finally {
      _deletingId = null;
      notifyListeners();
    }
  }

  /// Foto de un registro; cada una se descarga una sola vez.
  Future<Uint8List> photo(String photoId) =>
      _photos.putIfAbsent(photoId, () => _repository.getMealPhoto(photoId));
}
