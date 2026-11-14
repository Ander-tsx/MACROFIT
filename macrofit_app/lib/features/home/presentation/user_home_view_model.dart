import '../../../core/errors/api_exception.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../../goals/domain/entities/nutritional_goal.dart';
import '../../goals/domain/repositories/goals_repository.dart';
import 'home_view_model.dart';

/// Pantalla principal del rol `user`: sesión (de [HomeViewModel]) y meta vigente (HU-26).
class UserHomeViewModel extends HomeViewModel {
  UserHomeViewModel({required AuthRepository auth, required this._goals})
    : super(auth);

  final GoalsRepository _goals;

  NutritionalGoal? _goal;
  bool _isLoadingGoal = false;
  bool _hasNoGoal = false;
  String? _goalError;

  /// Meta vigente; `null` mientras no se ha cargado o si el usuario no tiene meta.
  NutritionalGoal? get goal => _goal;
  bool get isLoadingGoal => _isLoadingGoal;

  /// La API respondió `404 PROFILE_NOT_FOUND`: sin perfil ni meta del coach.
  bool get hasNoGoal => _hasNoGoal;

  /// Error al consultar la meta (p. ej. sin conexión); se puede reintentar.
  String? get goalError => _goalError;

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
}
