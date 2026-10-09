import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/validators/profile_validators.dart';

/// Para qué se abre el formulario.
enum ProfileFormMode {
  /// Primer acceso de un usuario sin perfil: al guardar, el router abre la pantalla principal.
  setup,

  /// Edición desde "Mi perfil": carga el perfil del backend y, al guardar, regresa.
  edit,
}

/// HU-03 — formulario del perfil inicial (alta y edición).
class ProfileFormViewModel extends ViewModel with FormStateMixin {
  ProfileFormViewModel({
    required this._profiles,
    required this._auth,
    required this.mode,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ProfileRepository _profiles;
  final AuthRepository _auth;
  final DateTime Function() _clock;
  final ProfileFormMode mode;

  // Mismos nombres que la API para mostrar los errores del backend en su campo.
  static const objectiveField = 'objective';
  static const levelField = 'level';
  static const trainingDaysField = 'training_days';
  static const weightField = 'weight_kg';
  static const heightField = 'height_cm';
  static const genderField = 'gender';
  static const birthDateField = 'birth_date';

  static const _apiFields = {
    objectiveField,
    levelField,
    trainingDaysField,
    weightField,
    heightField,
    genderField,
    birthDateField,
  };

  Objective? _objective;
  ExperienceLevel? _level;
  int? _trainingDays;
  String _weight = '';
  String _height = '';
  Gender? _gender;
  DateTime? _birthDate;

  bool _isLoading = false;
  String? _loadError;
  bool _isLoggingOut = false;

  Objective? get objective => _objective;
  ExperienceLevel? get level => _level;
  int? get trainingDays => _trainingDays;
  String get weight => _weight;
  String get height => _height;
  Gender? get gender => _gender;
  DateTime? get birthDate => _birthDate;

  bool get isEditing => mode == ProfileFormMode.edit;

  /// Cargando el perfil guardado (solo en edición).
  bool get isLoading => _isLoading;

  /// No se pudo cargar el perfil (solo en edición); la vista ofrece reintentar.
  String? get loadError => _loadError;

  bool get isLoggingOut => _isLoggingOut;

  /// Fecha de hoy para el selector y la validación de la edad.
  DateTime get today => _clock();

  void setObjective(Objective? value) =>
      _update(objectiveField, () => _objective = value);

  void setLevel(ExperienceLevel? value) =>
      _update(levelField, () => _level = value);

  void setTrainingDays(int? value) =>
      _update(trainingDaysField, () => _trainingDays = value);

  void setWeight(String value) => _update(weightField, () => _weight = value);

  void setHeight(String value) => _update(heightField, () => _height = value);

  void setGender(Gender? value) => _update(genderField, () => _gender = value);

  void setBirthDate(DateTime? value) => _update(
    birthDateField,
    () => _birthDate = value == null
        ? null
        : DateTime(value.year, value.month, value.day),
  );

  /// Edición: trae el perfil del backend (así se ven los últimos cambios al volver a abrir).
  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    try {
      _fill(await _profiles.getProfile());
    } on ApiException catch (error) {
      _loadError = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Valida y guarda. Devuelve `true` si el perfil quedó guardado.
  Future<bool> submit() async {
    if (isSubmitting) return false;

    final errors = <String, String?>{
      objectiveField: ProfileValidators.objective(_objective),
      levelField: ProfileValidators.level(_level),
      trainingDaysField: ProfileValidators.trainingDays(_trainingDays),
      weightField: ProfileValidators.weight(_weight),
      heightField: ProfileValidators.height(_height),
      genderField: ProfileValidators.gender(_gender),
      birthDateField: ProfileValidators.birthDate(_birthDate, today: today),
    }..removeWhere((_, message) => message == null);
    setFieldErrors(errors.cast<String, String>());
    setGeneralError(null);
    if (errors.isNotEmpty) {
      notifyListeners();
      return false;
    }

    final profile = Profile(
      objective: _objective!,
      level: _level!,
      trainingDays: _trainingDays!,
      weightKg: ProfileValidators.parseNumber(_weight)!,
      heightCm: ProfileValidators.parseNumber(_height)!,
      gender: _gender!,
      birthDate: _birthDate!,
    );

    setSubmitting(true);
    try {
      switch (mode) {
        case ProfileFormMode.setup:
          await _create(profile);
          // El router lleva a la pantalla principal al cambiar la sesión.
          await _auth.markProfileCompleted();
        case ProfileFormMode.edit:
          _fill(await _profiles.updateProfile(profile));
      }
      return true;
    } on ApiException catch (error) {
      applyApiError(error, knownFields: _apiFields);
      return false;
    } finally {
      setSubmitting(false);
    }
  }

  /// Cierra la sesión desde el formulario inicial (p. ej. para cambiar de cuenta).
  Future<void> logout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    notifyListeners();
    await _auth.logout();
  }

  Future<void> _create(Profile profile) async {
    try {
      await _profiles.createProfile(profile);
    } on ApiException catch (error) {
      // Ya existía (p. ej. se capturó en otro dispositivo): la cuenta ya tiene perfil.
      if (error.code != ApiErrorCode.profileAlreadyExists) rethrow;
    }
  }

  void _fill(Profile profile) {
    _objective = profile.objective;
    _level = profile.level;
    _trainingDays = profile.trainingDays;
    _weight = _formatNumber(profile.weightKg);
    _height = _formatNumber(profile.heightCm);
    _gender = profile.gender;
    _birthDate = profile.birthDate;
  }

  /// `70.0` → `"70"`, `72.5` → `"72.5"`.
  static String _formatNumber(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();

  void _update(String field, void Function() change) {
    change();
    clearFieldError(field);
    notifyListeners();
  }
}
