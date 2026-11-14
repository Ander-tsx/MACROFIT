import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/meal.dart';
import '../../domain/entities/meal_estimate.dart';
import '../../domain/repositories/meals_repository.dart';
import '../../domain/validators/meal_values_validator.dart';
import '../widgets/meal_texts.dart';

/// HU-08 — revisa y corrige los valores antes de guardar (RF-07). Precargado con
/// la estimación de HU-07, o vacío para la captura manual (CU-01 flujos 3a y 4a).
class MealFormViewModel extends ViewModel with FormStateMixin {
  MealFormViewModel({required this._repository, required this.draft}) {
    if (draft.estimated case final estimated?) {
      _initialCalories = _calories = formatAmount(estimated.caloriesKcal);
      _initialProtein = _protein = formatAmount(estimated.proteinG);
      _initialFat = _fat = formatAmount(estimated.fatG);
    }
  }

  final MealsRepository _repository;
  final MealDraft draft;

  // Mismos nombres que la API para mostrar los errores del backend en su campo.
  static const caloriesField = 'calories_kcal';
  static const proteinField = 'protein_g';
  static const fatField = 'fat_g';

  /// Errores de los valores estimados (`estimated.<campo>`, HU-08-API).
  static String estimatedField(String field) => 'estimated.$field';

  static const _apiFields = {
    caloriesField,
    proteinField,
    fatField,
    'estimated.$caloriesField',
    'estimated.$proteinField',
    'estimated.$fatField',
  };

  String _initialCalories = '';
  String _initialProtein = '';
  String _initialFat = '';
  String _calories = '';
  String _protein = '';
  String _fat = '';
  Meal? _saved;

  String get calories => _calories;
  String get protein => _protein;
  String get fat => _fat;

  /// Sin estimación: el formulario empieza vacío y se guarda sin `estimated`.
  bool get isManual => draft.isManual;

  /// Registro guardado; la vista sale del formulario cuando existe.
  Meal? get saved => _saved;

  /// Error de un campo: el del valor final o, si no hay, el de su estimado.
  String? errorFor(String field) =>
      fieldError(field) ??
      switch (fieldError(estimatedField(field))) {
        final message? => 'Valor estimado: $message',
        null => null,
      };

  void setCalories(String value) =>
      _update(caloriesField, () => _calories = value);

  void setProtein(String value) =>
      _update(proteinField, () => _protein = value);

  void setFat(String value) => _update(fatField, () => _fat = value);

  /// Valida y guarda con `POST /meals`. Devuelve `true` si quedó guardado.
  Future<bool> submit() async {
    if (isSubmitting || _saved != null) return false;

    final errors = <String, String?>{
      caloriesField: MealValuesValidator.calories(_calories),
      proteinField: MealValuesValidator.protein(_protein),
      fatField: MealValuesValidator.fat(_fat),
    }..removeWhere((_, message) => message == null);
    setFieldErrors(errors.cast<String, String>());
    setGeneralError(null);
    if (errors.isNotEmpty) {
      notifyListeners();
      return false;
    }

    setSubmitting(true);
    try {
      _saved = await _repository.createMeal(_newMeal());
      return true;
    } on ApiException catch (error) {
      applyApiError(error, knownFields: _apiFields);
      return false;
    } finally {
      setSubmitting(false);
    }
  }

  /// Sin corrección, los finales son exactamente los estimados (el texto
  /// precargado está redondeado a un decimal); con corrección, lo capturado.
  NewMeal _newMeal() {
    final estimated = draft.estimated;
    double value(String text, String initial, double? estimate) =>
        text == initial && estimate != null
        ? estimate
        : MealValuesValidator.parse(text)!;
    return NewMeal(
      photoId: draft.photo?.photoId,
      values: NutritionValues(
        caloriesKcal: value(
          _calories,
          _initialCalories,
          estimated?.caloriesKcal,
        ),
        proteinG: value(_protein, _initialProtein, estimated?.proteinG),
        fatG: value(_fat, _initialFat, estimated?.fatG),
      ),
      estimated: estimated,
    );
  }

  void _update(String field, void Function() change) {
    change();
    clearFieldError(field);
    clearFieldError(estimatedField(field));
    notifyListeners();
  }
}
