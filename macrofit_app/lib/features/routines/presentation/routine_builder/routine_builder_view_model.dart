import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/entities/routine.dart';
import '../../domain/repositories/routines_repository.dart';
import '../../domain/validators/routine_validator.dart';

/// Un ejercicio en el constructor, con sus campos tal como se capturan.
class RoutineEntry {
  const RoutineEntry({
    required this.key,
    required this.exerciseId,
    required this.name,
    required this.muscleGroup,
    required this.sets,
    required this.reps,
    required this.restSeconds,
  });

  /// Identificador local, estable al reordenar (para las `Key` de la lista).
  final int key;
  final String exerciseId;
  final String name;
  final String muscleGroup;
  final String sets;
  final String reps;
  final String restSeconds;

  RoutineEntry copyWith({String? sets, String? reps, String? restSeconds}) =>
      RoutineEntry(
        key: key,
        exerciseId: exerciseId,
        name: name,
        muscleGroup: muscleGroup,
        sets: sets ?? this.sets,
        reps: reps ?? this.reps,
        restSeconds: restSeconds ?? this.restSeconds,
      );
}

/// HU-18 — constructor de rutinas (RF-22, CU-04 pasos 2 a 4): crea una rutina
/// nueva o edita [initial]. Valida con [RoutineValidator] antes de enviar y
/// muestra en su campo los errores `400` de la API (flujos 4a y 5a).
class RoutineBuilderViewModel extends ViewModel with FormStateMixin {
  RoutineBuilderViewModel({required this._repository, this.initial}) {
    if (initial case final routine?) {
      _name = routine.name;
      _entries = [
        for (final exercise in routine.exercises)
          RoutineEntry(
            key: _nextKey++,
            exerciseId: exercise.exerciseId,
            name: exercise.name,
            muscleGroup: exercise.muscleGroup,
            sets: '${exercise.sets}',
            reps: '${exercise.reps}',
            restSeconds: '${exercise.restSeconds}',
          ),
      ];
    }
    _initialSnapshot = _snapshot();
  }

  /// Valores con los que llega un ejercicio recién agregado (acordado con el equipo).
  static const defaultSets = 3;
  static const defaultReps = 10;
  static const defaultRestSeconds = 60;

  final RoutinesRepository _repository;

  /// Rutina que se edita; `null` al crear.
  final Routine? initial;

  int _nextKey = 0;
  String _name = '';
  List<RoutineEntry> _entries = const [];
  late final String _initialSnapshot;
  Routine? _saved;

  bool get isEditing => initial != null;
  String get name => _name;
  List<RoutineEntry> get entries => _entries;

  /// Rutina guardada; la vista sale del constructor cuando existe.
  Routine? get saved => _saved;

  /// Hay algo distinto de lo que se abrió (para confirmar antes de salir).
  bool get hasChanges => _saved == null && _snapshot() != _initialSnapshot;

  /// Se pueden agregar más ejercicios sin pasar el máximo de la API.
  bool get canAddExercises => _entries.length < RoutineValidator.maxExercises;

  String? get nameError => fieldError(RoutineValidator.nameField);
  String? get exercisesError => fieldError(RoutineValidator.exercisesField);

  /// Error de un campo del ejercicio [index] (`exercise_id`, `sets`, `reps`,
  /// `rest_seconds`), o del ejercicio completo si la API lo señaló así.
  String? entryError(int index, String field) =>
      fieldError(RoutineValidator.exerciseField(index, field));

  /// Error que la API puso en el ejercicio sin campo (`exercises[i]`) o en su id.
  String? entryGeneralError(int index) =>
      fieldError('${RoutineValidator.exercisesField}[$index]') ??
      entryError(index, RoutineValidator.exerciseIdField);

  void setName(String value) {
    _name = value;
    clearFieldError(RoutineValidator.nameField);
    notifyListeners();
  }

  /// Agrega los ejercicios elegidos en el selector al final, con los valores por
  /// defecto. Se permite repetir un ejercicio (la API lo acepta).
  void addExercises(List<Exercise> exercises) {
    if (exercises.isEmpty) return;
    _entries = [
      ..._entries,
      for (final exercise in exercises)
        RoutineEntry(
          key: _nextKey++,
          exerciseId: exercise.id,
          name: exercise.name,
          muscleGroup: exercise.muscleGroup,
          sets: '$defaultSets',
          reps: '$defaultReps',
          restSeconds: '$defaultRestSeconds',
        ),
    ];
    _clearExerciseErrors();
    notifyListeners();
  }

  void remove(int index) {
    _entries = [..._entries]..removeAt(index);
    _clearExerciseErrors();
    notifyListeners();
  }

  /// Mueve el ejercicio de [from] a la posición final [to].
  void move(int from, int to) {
    if (from == to) return;
    final entries = [..._entries];
    final entry = entries.removeAt(from);
    entries.insert(to, entry);
    _entries = entries;
    _clearExerciseErrors();
    notifyListeners();
  }

  void setSets(int index, String value) => _updateEntry(
    index,
    RoutineValidator.setsField,
    (entry) => entry.copyWith(sets: value),
  );

  void setReps(int index, String value) => _updateEntry(
    index,
    RoutineValidator.repsField,
    (entry) => entry.copyWith(reps: value),
  );

  void setRestSeconds(int index, String value) => _updateEntry(
    index,
    RoutineValidator.restSecondsField,
    (entry) => entry.copyWith(restSeconds: value),
  );

  /// Valida y guarda (`POST` al crear, `PUT` al editar). Devuelve `true` si quedó
  /// guardada.
  Future<bool> submit() async {
    if (isSubmitting || _saved != null) return false;

    final errors = RoutineValidator.validate(
      name: _name,
      exercises: [
        for (final entry in _entries)
          (sets: entry.sets, reps: entry.reps, restSeconds: entry.restSeconds),
      ],
    );
    setFieldErrors(errors);
    setGeneralError(null);
    if (errors.isNotEmpty) {
      notifyListeners();
      return false;
    }

    setSubmitting(true);
    try {
      final draft = _draft();
      _saved = switch (initial) {
        final routine? => await _repository.updateRoutine(routine.id, draft),
        null => await _repository.createRoutine(draft),
      };
      return true;
    } on ApiException catch (error) {
      applyApiError(error, knownFields: _apiFields());
      return false;
    } finally {
      setSubmitting(false);
    }
  }

  RoutineDraft _draft() => RoutineDraft(
    name: _name.trim(),
    exercises: [
      for (final entry in _entries)
        RoutineExerciseDraft(
          exerciseId: entry.exerciseId,
          sets: RoutineValidator.parseInt(entry.sets)!,
          reps: RoutineValidator.parseInt(entry.reps)!,
          restSeconds: RoutineValidator.parseInt(entry.restSeconds)!,
        ),
    ],
  );

  /// Campos que el constructor sabe mostrar; otro error de la API va al general.
  Set<String> _apiFields() => {
    RoutineValidator.nameField,
    RoutineValidator.exercisesField,
    for (var i = 0; i < _entries.length; i++) ...[
      '${RoutineValidator.exercisesField}[$i]',
      for (final field in const [
        RoutineValidator.exerciseIdField,
        RoutineValidator.setsField,
        RoutineValidator.repsField,
        RoutineValidator.restSecondsField,
      ])
        RoutineValidator.exerciseField(i, field),
    ],
  };

  void _updateEntry(
    int index,
    String field,
    RoutineEntry Function(RoutineEntry) change,
  ) {
    _entries = [..._entries]..[index] = change(_entries[index]);
    clearFieldError(RoutineValidator.exerciseField(index, field));
    notifyListeners();
  }

  /// Los errores por ejercicio usan su posición: al agregar, quitar o reordenar
  /// ya no corresponden, así que se limpian (y el de la lista también).
  void _clearExerciseErrors() {
    setFieldErrors({
      for (final entry in fieldErrors.entries)
        if (!entry.key.startsWith(RoutineValidator.exercisesField))
          entry.key: entry.value,
    });
    setGeneralError(null);
  }

  String _snapshot() => [
    _name.trim(),
    for (final entry in _entries)
      '${entry.exerciseId}|${entry.sets.trim()}|${entry.reps.trim()}|'
          '${entry.restSeconds.trim()}',
  ].join('\n');
}
