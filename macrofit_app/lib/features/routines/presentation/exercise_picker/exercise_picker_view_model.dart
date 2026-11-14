import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/repositories/routines_repository.dart';

/// HU-18 — selector de ejercicios del catálogo (CU-04 paso 3): filtros por grupo
/// muscular y nivel (los aplica `GET /exercises`) y selección múltiple.
class ExercisePickerViewModel extends ViewModel {
  ExercisePickerViewModel(this._repository);

  final RoutinesRepository _repository;

  MuscleGroup? _muscleGroup;
  ExerciseLevel? _level;
  List<Exercise> _exercises = const [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;
  int _request = 0;

  // Conserva el orden en que se marcaron (así se agregan a la rutina).
  final Map<String, Exercise> _selected = {};

  /// `null` = todos los grupos.
  MuscleGroup? get muscleGroup => _muscleGroup;

  /// `null` = todos los niveles.
  ExerciseLevel? get level => _level;

  /// Ejercicios del catálogo con los filtros actuales.
  List<Exercise> get exercises => _exercises;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// El catálogo no tiene ejercicios con estos filtros.
  bool get hasNoResults => _hasLoaded && _exercises.isEmpty && _error == null;

  /// Seleccionados en el orden en que se marcaron (aunque ya no estén visibles).
  List<Exercise> get selected => List.unmodifiable(_selected.values);
  int get selectedCount => _selected.length;
  bool isSelected(Exercise exercise) => _selected.containsKey(exercise.id);

  /// Consulta el catálogo con los filtros actuales. Si mientras tanto cambia un
  /// filtro, la respuesta anterior se descarta.
  Future<void> load() async {
    final request = ++_request;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final exercises = await _repository.getExercises(
        muscleGroup: _muscleGroup,
        level: _level,
      );
      if (request != _request) return;
      _exercises = exercises;
      _hasLoaded = true;
    } on ApiException catch (error) {
      if (request != _request) return;
      _error = error.message;
    } finally {
      if (request == _request) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> setMuscleGroup(MuscleGroup? group) async {
    if (group == _muscleGroup) return;
    _muscleGroup = group;
    await load();
  }

  Future<void> setLevel(ExerciseLevel? level) async {
    if (level == _level) return;
    _level = level;
    await load();
  }

  void toggle(Exercise exercise) {
    if (_selected.remove(exercise.id) == null) {
      _selected[exercise.id] = exercise;
    }
    notifyListeners();
  }
}
