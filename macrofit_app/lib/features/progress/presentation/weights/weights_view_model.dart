import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../../profile/domain/validators/profile_validators.dart';
import '../../domain/entities/weight_entry.dart';
import '../../domain/repositories/weights_repository.dart';

/// HU-21 — registro e historial de peso.
class WeightsViewModel extends ViewModel with FormStateMixin {
  WeightsViewModel({required this._repository});

  final WeightsRepository _repository;

  List<WeightEntry> _weights = [];
  bool _isLoading = false;
  String? _loadError;
  String _weightInput = '';

  List<WeightEntry> get weights => _weights;
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  String get weightInput => _weightInput;

  void setWeightInput(String value) {
    _weightInput = value;
    clearFieldError('weight_kg');
    notifyListeners();
  }

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      _weights = await _repository.getWeights();
    } on ApiException catch (error) {
      _loadError = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registerWeight() async {
    final validationError = ProfileValidators.weight(_weightInput);
    if (validationError != null) {
      setFieldErrors({'weight_kg': validationError});
      notifyListeners();
      return false;
    }

    final weightValue = ProfileValidators.parseNumber(_weightInput)!;
    setSubmitting(true);
    setFieldErrors({});
    setGeneralError(null);

    try {
      final newEntry = await _repository.createWeight(weightValue);
      _weights = [newEntry, ..._weights];
      _weightInput = '';
      setSubmitting(false);
      return true;
    } on ApiException catch (error) {
      if (error.code == ApiErrorCode.validation) {
        applyApiError(error, knownFields: {'weight_kg'});
      } else {
        setGeneralError(error.message);
      }
      setSubmitting(false);
      return false;
    }
  }
}
