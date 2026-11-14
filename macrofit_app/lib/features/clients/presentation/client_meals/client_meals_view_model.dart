import 'dart:typed_data';

import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../../goals/domain/entities/coach_client.dart';
import '../../domain/entities/client_meal.dart';
import '../../domain/repositories/clients_repository.dart';

/// Totales del día (valores finales de cada registro).
typedef DayTotals = ({double calories, double proteinG, double fatG});

/// HU-25 — registro diario de comidas de un cliente (solo lectura, RN-07).
///
/// Empieza en el día de hoy (hora local del teléfono) y no permite días futuros.
class ClientMealsViewModel extends ViewModel {
  ClientMealsViewModel({
    required this._repository,
    required this.client,
    this._clock = DateTime.now,
  }) {
    _date = today;
  }

  final ClientsRepository _repository;
  final DateTime Function() _clock;
  final CoachClient client;

  late DateTime _date;
  List<ClientMeal> _meals = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isUnlinked = false;
  String? _error;
  int _request = 0;
  final _photos = <String, Future<Uint8List>>{};

  /// Día consultado (sin hora).
  DateTime get date => _date;
  List<ClientMeal> get meals => _meals;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// La API respondió `CLIENT_NOT_LINKED`: el cliente ya no está vinculado (RN-04).
  bool get isUnlinked => _isUnlinked;

  /// El día cargado no tiene registros (CU-03 3a).
  bool get isEmptyDay => _hasLoaded && _meals.isEmpty;

  bool get canGoForward => _date.isBefore(today);

  DateTime get today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  DayTotals get totals {
    var calories = 0.0, protein = 0.0, fat = 0.0;
    for (final meal in _meals) {
      calories += meal.caloriesKcal;
      protein += meal.proteinG;
      fat += meal.fatG;
    }
    return (calories: calories, proteinG: protein, fatG: fat);
  }

  /// Carga (o recarga) el día elegido. Si llega la respuesta de un día anterior
  /// después de cambiar de día, se descarta.
  Future<void> load() async {
    final request = ++_request;
    final date = _date;
    _isLoading = true;
    _hasLoaded = false;
    _error = null;
    _meals = const [];
    notifyListeners();
    try {
      final meals = await _repository.getClientMeals(client.id, date);
      if (request != _request) return;
      _meals = meals;
      _hasLoaded = true;
    } on ApiException catch (error) {
      if (request != _request) return;
      if (error.code == ApiErrorCode.clientNotLinked) {
        _isUnlinked = true;
      } else {
        _error = error.message;
      }
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

  /// Foto de un registro; cada `photo_url` se descarga una sola vez.
  Future<Uint8List> photo(String photoUrl) =>
      _photos.putIfAbsent(photoUrl, () => _repository.getMealPhoto(photoUrl));
}
