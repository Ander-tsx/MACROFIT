import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/user_routine.dart';
import '../../domain/repositories/my_routines_repository.dart';

/// HU-16 — «Mis rutinas» del usuario: recomendada y asignadas con su origen.
///
/// Se recarga al abrir la pantalla, al deslizar hacia abajo y al volver del
/// detalle (sin caché), así una rutina recién asignada aparece sin reiniciar la
/// app (RF-23).
class MyRoutinesListViewModel extends ViewModel {
  MyRoutinesListViewModel(this._repository);

  final MyRoutinesRepository _repository;

  List<UserRoutineSummary> _routines = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;
  bool _isRequesting = false;
  String? _requestError;

  /// Como las manda la API (la recomendada primero).
  List<UserRoutineSummary> get routines => _routines;
  bool get isLoading => _isLoading;

  /// Error de la última carga (sin conexión, servidor…).
  String? get error => _error;

  /// La API respondió sin rutinas.
  bool get hasNoRoutines => _hasLoaded && _routines.isEmpty && _error == null;

  /// Se está pidiendo la rutina recomendada (HU-15).
  bool get isRequesting => _isRequesting;
  String? get requestError => _requestError;

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

  /// Acceso a la rutina recomendada desde la lista vacía: la pide (HU-15),
  /// recarga la lista y devuelve su id para abrir el detalle. `null` si falló
  /// (el mensaje queda en [requestError]).
  Future<String?> requestRecommended() async {
    if (_isRequesting) return null;
    _isRequesting = true;
    _requestError = null;
    notifyListeners();
    String? id;
    try {
      id = (await _repository.requestRecommendedRoutine()).id;
    } on ApiException catch (error) {
      _requestError = error.code == ApiErrorCode.profileNotFound
          ? 'Completa tu perfil para recibir una rutina recomendada.'
          : error.message;
    } finally {
      _isRequesting = false;
      notifyListeners();
    }
    if (id != null) await load();
    return id;
  }
}
