import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/routine.dart';
import '../../domain/entities/routine_assignment.dart';
import '../../domain/repositories/routines_repository.dart';

/// Resultado de retirar la rutina de un cliente (HU-20).
enum RemoveAssignmentResult {
  /// Se retiró.
  removed,

  /// Ya estaba retirada (`ASSIGNMENT_NOT_FOUND`): se quita de la lista igual.
  alreadyRemoved,

  /// Falló (sin conexión, servidor…): el cliente sigue en la lista.
  failed,

  /// La persona canceló la confirmación.
  cancelled,
}

/// HU-20 — clientes con la rutina asignada y retiro por cliente (RF-24).
class RoutineAssignmentsViewModel extends ViewModel {
  RoutineAssignmentsViewModel({
    required this._repository,
    required this.routine,
  });

  final RoutinesRepository _repository;
  final Routine routine;

  List<RoutineAssignment> _assignments = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;
  String? _removingClientId;
  String? _removeError;

  /// Asignaciones activas, la más reciente primero (como las manda la API).
  List<RoutineAssignment> get assignments => _assignments;
  bool get isLoading => _isLoading;

  /// Error de la última carga.
  String? get error => _error;

  /// Error del último retiro (el cliente sigue en la lista).
  String? get removeError => _removeError;

  /// La API respondió que nadie tiene la rutina.
  bool get hasNoAssignments =>
      _hasLoaded && _assignments.isEmpty && _error == null;

  bool get isRemoving => _removingClientId != null;
  bool isRemovingClient(String clientId) => _removingClientId == clientId;

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _assignments = await _repository.getAssignments(routine.id);
      _hasLoaded = true;
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Retira la rutina de [assignment] si [confirm] (el diálogo de la vista)
  /// responde `true`, y lo quita de la lista.
  Future<RemoveAssignmentResult> remove(
    RoutineAssignment assignment,
    Future<bool> Function() confirm,
  ) async {
    if (isRemoving) return RemoveAssignmentResult.cancelled;
    if (!await confirm()) return RemoveAssignmentResult.cancelled;

    _removingClientId = assignment.clientId;
    _removeError = null;
    notifyListeners();
    var result = RemoveAssignmentResult.failed;
    try {
      await _repository.removeAssignment(routine.id, assignment.clientId);
      result = RemoveAssignmentResult.removed;
    } on ApiException catch (error) {
      if (error.code == ApiErrorCode.assignmentNotFound) {
        result = RemoveAssignmentResult.alreadyRemoved;
      } else {
        _removeError = error.message;
      }
    } finally {
      _removingClientId = null;
      if (result != RemoveAssignmentResult.failed) {
        _assignments = [
          for (final item in _assignments)
            if (item.clientId != assignment.clientId) item,
        ];
        _hasLoaded = true;
      }
      notifyListeners();
    }
    return result;
  }
}
