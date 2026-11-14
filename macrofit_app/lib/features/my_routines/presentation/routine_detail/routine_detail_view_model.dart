import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../../summary/domain/usecases/app_day.dart';
import '../../domain/entities/completed_session.dart';
import '../../domain/entities/user_routine.dart';
import '../../domain/repositories/my_routines_repository.dart';

/// Resultado de marcar una sesión como completada (HU-17).
enum CompleteSessionResult {
  /// Se registró hoy.
  completed,

  /// Ya estaba registrada hoy (`SESSION_ALREADY_COMPLETED`).
  alreadyCompleted,

  /// Falló (sin conexión, servidor…): se puede reintentar.
  failed,

  /// La rutina ya no está disponible (`ROUTINE_NOT_FOUND`).
  unavailable,

  /// La persona canceló la confirmación.
  cancelled,
}

/// HU-16 — detalle de una rutina del usuario: sesiones con sus ejercicios,
/// series, repeticiones y descanso.
/// HU-17 — marcar una sesión como completada y ver las completadas hoy.
class RoutineDetailViewModel extends ViewModel {
  RoutineDetailViewModel({
    required this._repository,
    required this.routineId,
    this._summary,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MyRoutinesRepository _repository;
  final String routineId;
  final UserRoutineSummary? _summary;
  final DateTime Function() _now;

  UserRoutine? _routine;
  bool _isLoading = false;
  String? _error;
  bool _isUnavailable = false;
  bool _unavailableHandled = false;

  List<CompletedSession> _completed = const [];
  String? _sessionsError;
  int? _completingNumber;
  String? _completeError;
  int? _failedNumber;

  UserRoutine? get routine => _routine;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Título mientras carga: el de la lista, si se abrió desde ella.
  String get title => _routine?.name ?? _summary?.name ?? 'Rutina';

  /// La rutina ya no está disponible (`ROUTINE_NOT_FOUND`: retirada,
  /// reemplazada o ajena).
  bool get isUnavailable => _isUnavailable;

  /// No se pudieron consultar las sesiones completadas (la rutina sí se muestra).
  String? get sessionsError => _sessionsError;

  /// Último error al marcar una sesión (sin conexión, servidor…).
  String? get completeError => _completeError;

  /// Sesión cuyo último intento falló (muestra el error y «Reintentar»).
  int? get lastFailedNumber => _failedNumber;

  /// Día de hoy en hora de México, el mismo criterio que la API.
  String get today => appDay(_now());

  /// Registro de hoy de la sesión [number], si ya se completó.
  CompletedSession? completedToday(int number) {
    final day = today;
    for (final session in _completed) {
      if (session.sessionNumber == number && session.date == day) {
        return session;
      }
    }
    return null;
  }

  bool isCompleting(int number) => _completingNumber == number;
  bool get isCompletingAny => _completingNumber != null;

  /// Carga la rutina y después sus sesiones completadas.
  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _routine = await _repository.getRoutine(routineId);
      await _loadSessions();
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

  /// Vuelve a consultar las sesiones completadas. Un error aquí no impide ver
  /// la rutina: se muestra aparte.
  Future<void> _loadSessions() async {
    try {
      _completed = await _repository.getCompletedSessions(routineId);
      _sessionsError = null;
    } on ApiException catch (error) {
      if (error.code == ApiErrorCode.routineNotFound) rethrow;
      _sessionsError = error.message;
    }
  }

  /// Marca la sesión [number] como completada hoy si [confirm] (el diálogo de
  /// la vista) responde `true`.
  Future<CompleteSessionResult> complete(
    int number,
    Future<bool> Function() confirm,
  ) async {
    if (isCompletingAny || completedToday(number) != null) {
      return CompleteSessionResult.cancelled;
    }
    if (!await confirm()) return CompleteSessionResult.cancelled;

    _completingNumber = number;
    _completeError = null;
    _failedNumber = null;
    notifyListeners();
    var result = CompleteSessionResult.failed;
    try {
      final session = await _repository.completeSession(routineId, number);
      _completed = [session, ..._completed];
      result = CompleteSessionResult.completed;
    } on ApiException catch (error) {
      switch (error.code) {
        case ApiErrorCode.sessionAlreadyCompleted:
          // Se registró desde otro dispositivo: se consulta para marcarla.
          result = CompleteSessionResult.alreadyCompleted;
          try {
            await _loadSessions();
          } on ApiException {
            // Si falla, la vista igual informa que ya estaba registrada.
          }
        case ApiErrorCode.routineNotFound:
          result = CompleteSessionResult.unavailable;
          _isUnavailable = true;
        default:
          _completeError = error.message;
          _failedNumber = number;
      }
    } finally {
      _completingNumber = null;
      notifyListeners();
    }
    return result;
  }

  /// `true` la primera vez que se consulta tras quedar no disponible: la vista
  /// avisa y regresa a la lista una sola vez.
  bool takeUnavailable() {
    if (!_isUnavailable || _unavailableHandled) return false;
    _unavailableHandled = true;
    return true;
  }
}
