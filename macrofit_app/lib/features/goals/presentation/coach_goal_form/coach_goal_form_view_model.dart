import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/coach_client.dart';
import '../../domain/entities/nutritional_goal.dart';
import '../../domain/repositories/coach_goals_repository.dart';
import '../../domain/validators/coach_goal_validators.dart';

/// HU-05 — formulario de meta de un cliente e historial de sus metas.
class CoachGoalFormViewModel extends ViewModel with FormStateMixin {
  CoachGoalFormViewModel({
    required this._repository,
    required this.client,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    final now = _clock();
    _effectiveFrom = DateTime(now.year, now.month, now.day);
  }

  final CoachGoalsRepository _repository;
  final DateTime Function() _clock;
  final CoachClient client;

  // Mismos nombres que la API para mostrar los errores del backend en su campo.
  static const caloriesField = 'calories';
  static const proteinField = 'protein_g';
  static const fatField = 'fat_g';
  static const effectiveFromField = 'effective_from';

  static const _apiFields = {
    caloriesField,
    proteinField,
    fatField,
    effectiveFromField,
  };

  String _calories = '';
  String _protein = '';
  String _fat = '';
  late DateTime _effectiveFrom;

  List<NutritionalGoal> _history = const [];
  bool _isLoading = false;
  String? _loadError;

  String get calories => _calories;
  String get protein => _protein;
  String get fat => _fat;
  DateTime get effectiveFrom => _effectiveFrom;
  DateTime get today => _clock();

  List<NutritionalGoal> get history => _history;
  bool get isLoading => _isLoading;

  /// No se pudo cargar el historial; la vista ofrece reintentar.
  String? get loadError => _loadError;

  void setCalories(String value) =>
      _update(caloriesField, () => _calories = value);

  void setProtein(String value) =>
      _update(proteinField, () => _protein = value);

  void setFat(String value) => _update(fatField, () => _fat = value);

  void setEffectiveFrom(DateTime value) => _update(
    effectiveFromField,
    () => _effectiveFrom = DateTime(value.year, value.month, value.day),
  );

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      _history = await _repository.getClientGoals(client.id);
    } on ApiException catch (error) {
      _loadError = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Valida y guarda la meta. Devuelve `true` si quedó guardada.
  Future<bool> submit() async {
    if (isSubmitting) return false;

    final errors = <String, String?>{
      caloriesField: CoachGoalValidators.calories(_calories),
      proteinField: CoachGoalValidators.protein(_protein),
      fatField: CoachGoalValidators.fat(_fat),
    }..removeWhere((_, message) => message == null);
    setFieldErrors(errors.cast<String, String>());
    setGeneralError(null);
    if (errors.isNotEmpty) {
      notifyListeners();
      return false;
    }

    setSubmitting(true);
    try {
      await _repository.setClientGoal(
        client.id,
        calories: CoachGoalValidators.parse(_calories)!,
        proteinG: CoachGoalValidators.parse(_protein)!,
        fatG: CoachGoalValidators.parse(_fat)!,
        effectiveFrom: _effectiveFrom,
      );
      await load();
      return true;
    } on ApiException catch (error) {
      applyApiError(error, knownFields: _apiFields);
      return false;
    } finally {
      setSubmitting(false);
    }
  }

  void _update(String field, void Function() change) {
    change();
    clearFieldError(field);
    notifyListeners();
  }
}
