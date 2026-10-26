import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../data/models/weight_model.dart';
import '../../domain/repositories/weights_repository.dart';
import '../../domain/validators/weight_validators.dart';

/// HU-21 — registro e historial de peso.
class WeightsViewModel extends ViewModel {
  WeightsViewModel({required this._repository});

  final WeightsRepository _repository;

  List<WeightModel> _weights = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _loadError;
  String _weightInput = '';
  Map<String, String> _fieldErrors = {};

  List<WeightModel> get weights => _weights;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get loadError => _loadError;
  String get weightInput => _weightInput;
  Map<String, String> get fieldErrors => _fieldErrors;

  void setWeightInput(String value) {
    _weightInput = value;
    _fieldErrors = {};
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
    final error = WeightValidators.weight(_weightInput);
    if (error != null) {
      _fieldErrors = {'weight_kg': error};
      notifyListeners();
      return false;
    }

    final weightValue = WeightValidators.parseNumber(_weightInput)!;
    _isSubmitting = true;
    _fieldErrors = {};
    notifyListeners();

    try {
      final newEntry = await _repository.createWeight(weightValue);
      _weights = [newEntry, ..._weights];
      _weightInput = '';
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (error.code == ApiErrorCode.validation && error.fields.isNotEmpty) {
        _fieldErrors = error.fields;
      } else {
        _fieldErrors = {'weight_kg': error.message};
      }
      notifyListeners();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
