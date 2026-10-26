import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/platform/share_service.dart';
import '../features/auth/domain/entities/auth_state.dart';
import '../features/auth/domain/entities/role.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/login/login_view.dart';
import '../features/auth/presentation/login/login_view_model.dart';
import '../features/auth/presentation/register/register_view.dart';
import '../features/auth/presentation/register/register_view_model.dart';
import '../features/auth/presentation/splash/splash_view.dart';
import '../features/clients/domain/entities/client_summary.dart';
import '../features/clients/domain/repositories/clients_repository.dart';
import '../features/clients/presentation/client_detail/client_detail_view.dart';
import '../features/clients/presentation/client_detail/client_detail_view_model.dart';
import '../features/clients/presentation/client_meals/client_meals_view.dart';
import '../features/clients/presentation/client_meals/client_meals_view_model.dart';
import '../features/clients/presentation/clients_list/clients_list_view.dart';
import '../features/clients/presentation/clients_list/clients_list_view_model.dart';
import '../features/goals/domain/entities/coach_client.dart';
import '../features/goals/domain/repositories/coach_goals_repository.dart';
import '../features/goals/presentation/coach_goal_form/coach_goal_form_view.dart';
import '../features/goals/presentation/coach_goal_form/coach_goal_form_view_model.dart';
import '../features/home/presentation/coach_home_view.dart';
import '../features/home/presentation/home_view_model.dart';
import '../features/home/presentation/user_home_view.dart';
import '../features/invite_code/domain/repositories/invite_code_repository.dart';
import '../features/invite_code/presentation/invite_code/invite_code_view.dart';
import '../features/invite_code/presentation/invite_code/invite_code_view_model.dart';
import '../features/legal/domain/repositories/legal_repository.dart';
import '../features/legal/presentation/privacy_notice/privacy_notice_view.dart';
import '../features/legal/presentation/privacy_notice/privacy_notice_view_model.dart';
import '../features/profile/domain/repositories/profile_repository.dart';
import '../features/profile/presentation/profile_form/profile_form_view.dart';
import '../features/profile/presentation/profile_form/profile_form_view_model.dart';
import 'routes.dart';

/// Crea el router. Escucha al [AuthRepository]: cada cambio de sesión vuelve a
/// evaluar [resolveRedirect], así que login, logout y sesión expirada navegan solos.
GoRouter createRouter(AuthRepository auth) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: auth,
    redirect: (context, state) =>
        resolveRedirect(auth.state, state.matchedLocation),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashView()),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, _) => ChangeNotifierProvider(
          create: (context) => LoginViewModel(context.read<AuthRepository>()),
          child: const LoginView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, _) => ChangeNotifierProvider(
          create: (context) =>
              RegisterViewModel(context.read<AuthRepository>()),
          child: const RegisterView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.privacyNotice,
        builder: (context, _) => ChangeNotifierProvider(
          create: (context) =>
              PrivacyNoticeViewModel(context.read<LegalRepository>())..load(),
          child: const PrivacyNoticeView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.userHome,
        builder: (context, _) => ChangeNotifierProvider(
          create: (context) => HomeViewModel(context.read<AuthRepository>()),
          child: const UserHomeView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        builder: (context, _) => ChangeNotifierProvider(
          create: (context) => ProfileFormViewModel(
            profiles: context.read<ProfileRepository>(),
            auth: context.read<AuthRepository>(),
            mode: ProfileFormMode.setup,
          ),
          child: const ProfileFormView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (context, _) => ChangeNotifierProvider(
          create: (context) => ProfileFormViewModel(
            profiles: context.read<ProfileRepository>(),
            auth: context.read<AuthRepository>(),
            mode: ProfileFormMode.edit,
          )..load(),
          child: const ProfileFormView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.coachHome,
        builder: (context, _) => ChangeNotifierProvider(
          create: (context) => HomeViewModel(context.read<AuthRepository>()),
          child: const CoachHomeView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.coachInviteCode,
        builder: (context, _) => ChangeNotifierProvider(
          create: (context) => InviteCodeViewModel(
            repository: context.read<InviteCodeRepository>(),
            shareService: context.read<ShareService>(),
          )..load(),
          child: const InviteCodeView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.coachClients,
        builder: (context, _) => ChangeNotifierProvider(
          create: (context) =>
              ClientsListViewModel(context.read<ClientsRepository>())..load(),
          child: const ClientsListView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.coachClientGoalsPattern,
        // Sin el cliente (p. ej. al restaurar la ruta) se vuelve a la lista.
        redirect: (_, state) =>
            state.extra is CoachClient ? null : AppRoutes.coachClients,
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => CoachGoalFormViewModel(
            repository: context.read<CoachGoalsRepository>(),
            client: state.extra! as CoachClient,
          )..load(),
          child: const CoachGoalFormView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.coachClientMealsPattern,
        // Sin el cliente (p. ej. al restaurar la ruta) se vuelve a la lista.
        redirect: (_, state) =>
            state.extra is CoachClient ? null : AppRoutes.coachClients,
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => ClientMealsViewModel(
            repository: context.read<ClientsRepository>(),
            client: state.extra! as CoachClient,
          )..load(),
          child: const ClientMealsView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.coachClientDetailPattern,
        // Sin el cliente (p. ej. al restaurar la ruta) se vuelve a la lista.
        redirect: (_, state) =>
            state.extra is ClientSummary ? null : AppRoutes.coachClients,
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => ClientDetailViewModel(
            repository: context.read<ClientsRepository>(),
            client: state.extra! as ClientSummary,
          ),
          child: const ClientDetailView(),
        ),
      ),
    ],
  );
}

/// Pantalla principal de cada rol.
String homeFor(Role role) => switch (role) {
  Role.user => AppRoutes.userHome,
  Role.coach => AppRoutes.coachHome,
};

/// Regla de navegación según la sesión. Función pura para poder probarla.
///
/// - Sesión desconocida → carga inicial.
/// - Sin sesión → solo login, registro y aviso; cualquier otra ruta va a login
///   (por eso el botón atrás no regresa a pantallas protegidas tras cerrar sesión).
/// - Con sesión → la pantalla principal de su rol; nunca la del otro rol ni
///   login/registro. El aviso de privacidad sigue disponible.
/// - Usuario sin perfil (HU-03) → solo el formulario de perfil inicial hasta
///   completarlo. Con perfil: su pantalla principal y "Mi perfil".
///   Un coach nunca ve el formulario.
String? resolveRedirect(AuthState state, String location) {
  switch (state) {
    case AuthUnknown():
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case Unauthenticated():
      return AppRoutes.public.contains(location) ? null : AppRoutes.login;
    case Authenticated(:final user):
      if (location == AppRoutes.privacyNotice) return null;
      switch (user.role) {
        case Role.user when !user.profileCompleted:
          return location == AppRoutes.profileSetup
              ? null
              : AppRoutes.profileSetup;
        case Role.user:
          return AppRoutes.userRoutes.contains(location)
              ? null
              : AppRoutes.userHome;
        case Role.coach:
          return AppRoutes.isCoachRoute(location) ? null : AppRoutes.coachHome;
      }
  }
}
