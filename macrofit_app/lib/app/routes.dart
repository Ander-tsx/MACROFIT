/// Rutas de la app. Usa siempre estas constantes, nunca cadenas sueltas.
abstract final class AppRoutes {
  /// Carga inicial mientras se lee la sesión guardada.
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const privacyNotice = '/privacy';

  /// Pantalla principal del rol `user`.
  static const userHome = '/user';

  /// HU-03: perfil inicial obligatorio de un usuario sin perfil.
  static const profileSetup = '/profile/setup';

  /// HU-03: edición del perfil ("Mi perfil") del rol `user`.
  static const profileEdit = '/user/profile';

  /// HU-06: tomar o elegir la foto de la comida y subirla ("Registrar comida").
  /// Es subruta del inicio: al abrirla con `go` el inicio queda debajo.
  static const mealPhotoChild = 'meals/photo';
  static const mealPhoto = '$userHome/$mealPhotoChild';

  /// HU-07: estimación nutricional de la foto subida. Recibe la foto en
  /// `extra` (`MealPhotoUpload`); sin ella vuelve al inicio.
  static const mealEstimateChild = 'meals/estimate';
  static const mealEstimate = '$userHome/$mealEstimateChild';

  /// HU-08: revisar y corregir los valores (o capturarlos a mano) y guardar.
  /// Recibe un `MealDraft` en `extra`; sin él vuelve al inicio.
  static const mealFormChild = 'meals/form';
  static const mealForm = '$userHome/$mealFormChild';

  /// HU-11: resumen semanal del usuario (7 días contra la meta de cada día).
  static const weeklySummaryChild = 'summary';
  static const weeklySummary = '$userHome/$weeklySummaryChild';

  /// Pantalla principal del rol `coach`.
  static const coachHome = '/coach';

  /// HU-12: código de invitación del coach (ver, copiar, compartir y regenerar).
  static const coachInviteCode = '/coach/invite-code';

  /// HU-24: clientes vinculados del coach con búsqueda.
  static const coachClients = '/coach/clients';

  /// HU-24: detalle de un cliente (acceso a sus metas y comidas).
  static const coachClientDetailPattern = '/coach/clients/:clientId';
  static String coachClientDetail(String clientId) =>
      '/coach/clients/$clientId';

  /// HU-25: registro diario de comidas de un cliente (solo lectura).
  static const coachClientMealsPattern = '/coach/clients/:clientId/meals';
  static String coachClientMeals(String clientId) =>
      '/coach/clients/$clientId/meals';

  /// HU-05: meta e historial de un cliente.
  static const coachClientGoalsPattern = '/coach/clients/:clientId/goals';
  static String coachClientGoals(String clientId) =>
      '/coach/clients/$clientId/goals';

  /// Pantallas del rol `coach`: su principal y las que cuelgan de ella.
  static bool isCoachRoute(String location) =>
      location == coachHome || location.startsWith('$coachHome/');

  /// Rutas visibles sin sesión.
  static const public = {login, register, privacyNotice};

  /// Rutas de un usuario con perfil completo (además del aviso de privacidad).
  static const userRoutes = {
    userHome,
    profileEdit,
    mealPhoto,
    mealEstimate,
    mealForm,
    weeklySummary,
  };
}
