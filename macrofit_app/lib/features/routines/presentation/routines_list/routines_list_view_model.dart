import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/routine.dart';
import '../../domain/repositories/routines_repository.dart';

/// HU-18 — lista de rutinas del coach (CU-04 paso 1) con eliminación confirmada.
class RoutinesListViewModel extends ViewModel {
  RoutinesListViewModel(this._repository);

  final RoutinesRepository _repository;

  List<Routine> _routines = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;
  String? _deletingId;

  /// La editada más recientemente primero (como las manda la API).
  List<Routine> get routines => _routines;
  bool get isLoading => _isLoading;

  /// Error de la última carga o eliminación.
  String? get error => _error;

  /// La API respondió sin rutinas.
  bool get hasNoRoutines => _hasLoaded && _routines.isEmpty;

  /// Hay una eliminación en curso.
  bool get isDeleting => _deletingId != null;
  bool isDeletingRoutine(Routine routine) => _deletingId == routine.id;

  /// Carga (o recarga) la lista. Si falla, conserva la última lista cargada.
  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _routines = await _repository.getRoutines();
      _hasLoaded = true;
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Elimina [routine] si [confirm] (el diálogo de la vista) responde `true` y
  /// después recarga la lista. Devuelve `true` si se eliminó.
  ///
  /// Si la API responde `ROUTINE_NOT_FOUND` la rutina ya no existe: se quita de
  /// la lista igualmente. Con otro error la rutina se queda y se muestra el mensaje.
  Future<bool> delete(Routine routine, Future<bool> Function() confirm) async {
    if (isDeleting) return false;
    if (!await confirm()) return false;

    _deletingId = routine.id;
    _error = null;
    notifyListeners();
    var deleted = false;
    try {
      await _repository.deleteRoutine(routine.id);
      deleted = true;
    } on ApiException catch (error) {
      if (error.code == ApiErrorCode.routineNotFound) {
        deleted = true;
      } else {
        _error = error.message;
      }
    } finally {
      _deletingId = null;
      if (deleted) {
        _routines = [
          for (final item in _routines)
            if (item.id != routine.id) item,
        ];
      }
      notifyListeners();
    }
    if (deleted) await load();
    return deleted;
  }
}
