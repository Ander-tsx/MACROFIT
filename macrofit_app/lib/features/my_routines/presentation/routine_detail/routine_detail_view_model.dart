import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/user_routine.dart';
import '../../domain/repositories/my_routines_repository.dart';

/// HU-16 — detalle de una rutina del usuario: sesiones con sus ejercicios,
/// series, repeticiones y descanso.
class RoutineDetailViewModel extends ViewModel {
  RoutineDetailViewModel({
    required this._repository,
    required this.routineId,
    this._summary,
  });

  final MyRoutinesRepository _repository;
  final String routineId;
  final UserRoutineSummary? _summary;

  UserRoutine? _routine;
  bool _isLoading = false;
  String? _error;
  bool _isUnavailable = false;
  bool _unavailableHandled = false;

  UserRoutine? get routine => _routine;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Título mientras carga: el de la lista, si se abrió desde ella.
  String get title => _routine?.name ?? _summary?.name ?? 'Rutina';

  /// La rutina ya no está disponible (`ROUTINE_NOT_FOUND`: retirada,
  /// reemplazada o ajena).
  bool get isUnavailable => _isUnavailable;

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _routine = await _repository.getRoutine(routineId);
    } on ApiException catch (error) {
      if (error.code == ApiErrorCode.routineNotFound) {
        _isUnavailable = true;
      } else {
        _error = error.message;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// `true` la primera vez que se consulta tras quedar no disponible: la vista
  /// avisa y regresa a la lista una sola vez.
  bool takeUnavailable() {
    if (!_isUnavailable || _unavailableHandled) return false;
    _unavailableHandled = true;
    return true;
  }
}
