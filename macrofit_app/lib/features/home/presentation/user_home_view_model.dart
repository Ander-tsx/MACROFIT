import '../../../core/errors/api_exception.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../../goals/domain/entities/nutritional_goal.dart';
import '../../goals/domain/repositories/goals_repository.dart';
import '../../summary/domain/entities/day_summary.dart';
import '../../summary/domain/repositories/summary_repository.dart';
import '../../summary/domain/usecases/app_day.dart';
import 'home_view_model.dart';

/// Pantalla principal del rol `user`: sesión (de [HomeViewModel]), meta vigente (HU-26)
/// y resumen del día (HU-10).
class UserHomeViewModel extends HomeViewModel {
  UserHomeViewModel({
    required AuthRepository auth,
    required this._goals,
    required this._summary,
    this._clock = DateTime.now,
  }) : super(auth);

  final GoalsRepository _goals;
  final SummaryRepository _summary;
  final DateTime Function() _clock;

  NutritionalGoal? _goal;
  bool _isLoadingGoal = false;
  bool _hasNoGoal = false;
  String? _goalError;

  DaySummary? _daySummary;
  bool _isLoadingSummary = false;
  bool _hasNoSummary = false;
  String? _summaryError;

  /// Meta vigente; `null` mientras no se ha cargado o si el usuario no tiene meta.
  NutritionalGoal? get goal => _goal;
  bool get isLoadingGoal => _isLoadingGoal;

  /// La API respondió `404 PROFILE_NOT_FOUND`: sin perfil ni meta del coach.
  bool get hasNoGoal => _hasNoGoal;

  /// Error al consultar la meta (p. ej. sin conexión); se puede reintentar.
  String? get goalError => _goalError;

  /// Resumen del día de hoy; `null` mientras no se ha cargado o si no hay meta.
  DaySummary? get daySummary => _daySummary;
  bool get isLoadingSummary => _isLoadingSummary;

  /// El resumen respondió `404 PROFILE_NOT_FOUND`: sin perfil ni meta, no hay con qué comparar.
  bool get hasNoSummary => _hasNoSummary;

  /// Error al consultar el resumen (p. ej. sin conexión); se puede reintentar.
  String? get summaryError => _summaryError;

  /// Consulta de nuevo la meta (HU-26) y el resumen del día (HU-10).
  Future<void> refresh() => Future.wait([loadGoal(), loadSummary()]);

  /// HU-26 — consulta (o vuelve a consultar) la meta vigente. Si falla por red,
  /// conserva la última meta cargada.
  Future<void> loadGoal() async {
    if (_isLoadingGoal) return;
    _isLoadingGoal = true;
    _goalError = null;
    notifyListeners();
    try {
      _goal = await _goals.getCurrentGoal();
      _hasNoGoal = false;
    } on ApiException catch (error) {
      if (error.code == ApiErrorCode.profileNotFound) {
        _goal = null;
        _hasNoGoal = true;
      } else {
        _goalError = error.message;
      }
    } finally {
      _isLoadingGoal = false;
      notifyListeners();
    }
  }

  /// HU-10 — consulta (o vuelve a consultar) el resumen de hoy en la zona horaria
  /// de la app. Si falla por red, conserva el último resumen cargado.
  Future<void> loadSummary() async {
    if (_isLoadingSummary) return;
    _isLoadingSummary = true;
    _summaryError = null;
    notifyListeners();
    try {
      _daySummary = await _summary.getDaily(appDay(_clock()));
      _hasNoSummary = false;
    } on ApiException catch (error) {
      if (error.code == ApiErrorCode.profileNotFound) {
        _daySummary = null;
        _hasNoSummary = true;
      } else {
        _summaryError = error.message;
      }
    } finally {
      _isLoadingSummary = false;
      notifyListeners();
    }
  }
}
