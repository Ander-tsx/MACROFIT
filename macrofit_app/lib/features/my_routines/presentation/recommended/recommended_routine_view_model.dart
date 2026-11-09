import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/user_routine.dart';
import '../../domain/repositories/my_routines_repository.dart';

/// Resultado de pedir la rutina recomendada.
enum GenerateRoutineResult { generated, cancelled, failed }

/// HU-15 — solicitar y mostrar la rutina recomendada (RF-14).
///
/// La API solo genera (no hay consulta de la recomendada con objetivo y nivel),
/// así que al abrir se revisa en la lista si ya hay una vigente: generar otra la
/// reemplaza y por eso pide confirmación.
class RecommendedRoutineViewModel extends ViewModel {
  RecommendedRoutineViewModel(this._repository);

  final MyRoutinesRepository _repository;

  RecommendedRoutine? _routine;
  UserRoutineSummary? _existing;
  bool _isLoading = false;
  String? _loadError;
  bool _isGenerating = false;
  String? _generateError;
  bool _needsProfile = false;

  /// Rutina generada en esta pantalla.
  RecommendedRoutine? get routine => _routine;

  /// Recomendada vigente encontrada al abrir.
  UserRoutineSummary? get existing => _existing;

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  bool get isGenerating => _isGenerating;
  String? get generateError => _generateError;

  /// La API respondió `PROFILE_NOT_FOUND`.
  bool get needsProfile => _needsProfile;

  /// Revisa si el usuario ya tiene una recomendada vigente.
  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      final routines = await _repository.getRoutines();
      _existing = routines
          .where((routine) => routine.origin == RoutineOrigin.system)
          .firstOrNull;
    } on ApiException catch (error) {
      _loadError = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Genera la rutina. Si ya hay una, primero pide [confirmReplace].
  Future<GenerateRoutineResult> generate(
    Future<bool> Function() confirmReplace,
  ) async {
    if (_isGenerating) return GenerateRoutineResult.cancelled;
    if (_routine != null || _existing != null) {
      if (!await confirmReplace() || _isGenerating) {
        return GenerateRoutineResult.cancelled;
      }
    }
    _isGenerating = true;
    _generateError = null;
    _needsProfile = false;
    notifyListeners();
    try {
      final routine = await _repository.requestRecommendedRoutine();
      _routine = routine;
      _existing = routine.toSummary();
      return GenerateRoutineResult.generated;
    } on ApiException catch (error) {
      _needsProfile = error.code == ApiErrorCode.profileNotFound;
      _generateError = _needsProfile
          ? 'Completa tu perfil para recibir una rutina recomendada.'
          : error.message;
      return GenerateRoutineResult.failed;
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }
}
