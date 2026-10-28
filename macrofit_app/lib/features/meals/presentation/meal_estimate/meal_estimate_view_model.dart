import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/meal.dart';
import '../../domain/entities/meal_estimate.dart';
import '../../domain/entities/meal_photo.dart';
import '../../domain/repositories/meals_repository.dart';

/// Qué puede hacer la persona cuando la estimación no salió.
enum EstimateFailure {
  /// `422 FOOD_NOT_RECOGNIZED`: solo la captura manual (CU-01 flujo 4a).
  notRecognized,

  /// `502`, `504`, sin red u otro error: reintentar o capturar a mano (CU-01 flujo 3a, RNF-11).
  retryable,
}

/// HU-07 — estima calorías, proteína y grasa de la foto subida (RF-06).
class MealEstimateViewModel extends ViewModel {
  MealEstimateViewModel({required this._repository, required this.upload});

  final MealsRepository _repository;

  /// Foto subida en HU-06.
  final MealPhotoUpload upload;

  static const notRecognizedMessage =
      'No reconocimos comida en la foto. Captura los valores a mano.';
  static const providerErrorMessage =
      'El servicio de estimación no está disponible en este momento. '
      'Vuelve a intentarlo o captura los valores a mano.';
  static const providerTimeoutMessage =
      'La estimación tardó demasiado. Vuelve a intentarlo o captura los valores a mano.';

  /// Leyenda obligatoria junto a los valores (RNF-07, RN-09).
  static const disclaimer =
      'Estos valores son una estimación a partir de la foto y no una recomendación médica.';

  MealEstimate? _estimate;
  EstimateFailure? _failure;
  String? _error;
  bool _isLoading = false;

  MealEstimate? get estimate => _estimate;
  EstimateFailure? get failure => _failure;
  String? get error => _error;
  bool get isLoading => _isLoading;

  bool get canRetry => _failure == EstimateFailure.retryable;

  /// Lo que recibe el formulario de HU-08: con la estimación, sus totales
  /// precargados; sin ella (captura manual), solo la foto.
  MealDraft get formDraft =>
      MealDraft(photo: upload, estimated: _estimate?.totals);

  /// Pide la estimación. Se llama al abrir la pantalla y con **Reintentar**.
  Future<void> load() async {
    if (_isLoading || _estimate != null) return;
    _isLoading = true;
    _failure = null;
    _error = null;
    notifyListeners();
    try {
      _estimate = await _repository.estimate(upload.photoId);
    } on ApiException catch (error) {
      if (error.code == ApiErrorCode.foodNotRecognized) {
        _failure = EstimateFailure.notRecognized;
        _error = notRecognizedMessage;
      } else {
        _failure = EstimateFailure.retryable;
        _error = switch (error.code) {
          ApiErrorCode.foodProviderError => providerErrorMessage,
          ApiErrorCode.foodProviderTimeout => providerTimeoutMessage,
          _ => error.message,
        };
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> retry() => load();
}
