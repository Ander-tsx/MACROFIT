import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../../clients/domain/entities/client_summary.dart';
import '../../../clients/domain/repositories/clients_repository.dart';
import '../../../clients/domain/usecases/filter_clients_by_name.dart';
import '../../domain/entities/routine.dart';
import '../../domain/repositories/routines_repository.dart';

/// HU-19 — asignar una rutina a uno o varios clientes vinculados (RF-23, RN-04,
/// CU-04 pasos 5 y 6).
///
/// Carga los clientes vinculados (`GET /coach/clients`) y quiénes ya tienen la
/// rutina (`GET /coach/routines/{id}/assignments`). Los que ya la tienen quedan
/// marcados y bloqueados: no se pueden seleccionar ni se envían otra vez.
class AssignRoutineViewModel extends ViewModel {
  AssignRoutineViewModel({
    required this.routine,
    required this._routinesRepository,
    required this._clientsRepository,
  });

  /// Rutina que se asigna (ya guardada: salir sin asignar no la pierde, CU-04 5a).
  final Routine routine;

  final RoutinesRepository _routinesRepository;
  final ClientsRepository _clientsRepository;

  List<ClientSummary> _clients = const [];
  Set<String> _assignedIds = const {};
  // Conserva el orden en que se marcaron.
  final Set<String> _selectedIds = <String>{};
  String _query = '';
  bool _isLoading = false;
  bool _hasLoaded = false;
  bool _isAssigning = false;
  String? _error;
  int _lastAssignedCount = 0;

  /// Clientes vinculados, ordenados por nombre (como los manda la API).
  List<ClientSummary> get clients => _clients;

  /// Clientes que coinciden con la búsqueda.
  List<ClientSummary> get visibleClients =>
      filterClientsByName(_clients, _query);

  String get query => _query;
  bool get isLoading => _isLoading;
  bool get isAssigning => _isAssigning;

  /// Error de la última carga o asignación, listo para mostrar.
  String? get error => _error;

  /// El coach no tiene clientes vinculados: primero debe vincularlos.
  bool get hasNoClients => _hasLoaded && _clients.isEmpty;

  /// Hay clientes, pero ninguno coincide con la búsqueda.
  bool get hasNoMatches => _clients.isNotEmpty && visibleClients.isEmpty;

  /// Todos los clientes vinculados ya tienen la rutina.
  bool get allAssigned =>
      _clients.isNotEmpty && _clients.every((client) => isAssigned(client));

  /// El cliente ya tiene la rutina asignada (se muestra marcado y bloqueado).
  bool isAssigned(ClientSummary client) => _assignedIds.contains(client.id);

  /// Marcado por el coach en esta pantalla (no incluye a los ya asignados).
  bool isSelected(ClientSummary client) => _selectedIds.contains(client.id);

  /// Clientes elegidos, en el orden en que se marcaron.
  List<ClientSummary> get selectedClients => [
    for (final id in _selectedIds) ?_clientById(id),
  ];

  int get selectedCount => _selectedIds.length;

  /// Se puede enviar: hay al menos un cliente elegido y nada en curso.
  bool get canAssign => _selectedIds.isNotEmpty && !_isAssigning && !_isLoading;

  /// Aviso de éxito de la última asignación.
  String get successMessage => _lastAssignedCount == 1
      ? '«${routine.name}» se asignó a 1 cliente.'
      : '«${routine.name}» se asignó a $_lastAssignedCount clientes.';

  /// Carga (o recarga) clientes y asignaciones. Si falla, conserva lo último
  /// cargado y muestra el error.
  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final clients = await _clientsRepository.getClients();
      final assignments = await _routinesRepository.getAssignments(routine.id);
      _clients = clients;
      _assignedIds = {for (final item in assignments) item.clientId};
      final linkedIds = {for (final client in clients) client.id};
      // Un cliente que se desvinculó o que ya tiene la rutina deja de estar elegido.
      _selectedIds.removeWhere(
        (id) => !linkedIds.contains(id) || _assignedIds.contains(id),
      );
      _hasLoaded = true;
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Filtra la lista ya cargada; no hace otra petición.
  void search(String query) {
    _query = query;
    notifyListeners();
  }

  /// Marca o desmarca [client]. Los que ya tienen la rutina no cambian.
  void toggle(ClientSummary client) {
    if (_isAssigning || isAssigned(client)) return;
    if (!_selectedIds.remove(client.id)) _selectedIds.add(client.id);
    notifyListeners();
  }

  /// Asigna la rutina a los clientes elegidos si [confirm] (el resumen que
  /// muestra la vista) responde `true`. Devuelve `true` si se asignó.
  ///
  /// Con `403 CLIENT_NOT_LINKED` la API no asigna a ninguno: se indica qué
  /// clientes ya no están vinculados, se quitan de la selección, se recarga la
  /// lista y el resto queda elegido para volver a confirmar.
  Future<bool> assign(
    Future<bool> Function(List<ClientSummary> clients) confirm,
  ) async {
    if (!canAssign) return false;
    final chosen = selectedClients;
    if (!await confirm(chosen)) return false;

    final ids = [for (final client in chosen) client.id];
    _isAssigning = true;
    _error = null;
    notifyListeners();
    String? unlinkedMessage;
    try {
      await _routinesRepository.assignRoutine(routine.id, ids);
      _assignedIds = {..._assignedIds, ...ids};
      _selectedIds.clear();
      _lastAssignedCount = ids.length;
      return true;
    } on ApiException catch (error) {
      if (error.code == ApiErrorCode.clientNotLinked) {
        final unlinked = _unlinkedClients(error, chosen);
        _selectedIds.removeAll([for (final client in unlinked) client.id]);
        unlinkedMessage = _unlinkedText(unlinked, error.message);
      } else {
        _error = error.message;
      }
      return false;
    } finally {
      _isAssigning = false;
      notifyListeners();
      if (unlinkedMessage != null) {
        await load();
        // El aviso del desvinculado se conserva salvo que la recarga también falle.
        _error ??= unlinkedMessage;
        notifyListeners();
      }
    }
  }

  ClientSummary? _clientById(String id) {
    for (final client in _clients) {
      if (client.id == id) return client;
    }
    return null;
  }

  /// Clientes señalados en `fields["client_ids[i]"]`, según el orden enviado.
  static List<ClientSummary> _unlinkedClients(
    ApiException error,
    List<ClientSummary> sent,
  ) {
    final pattern = RegExp(r'^client_ids\[(\d+)\]$');
    return [
      for (final (index, client) in sent.indexed)
        if (error.fields.keys.any(
          (key) => pattern.firstMatch(key)?.group(1) == '$index',
        ))
          client,
    ];
  }

  static String _unlinkedText(List<ClientSummary> unlinked, String fallback) {
    if (unlinked.isEmpty) return '$fallback $_reloaded';
    final names = [for (final client in unlinked) client.name];
    final joined = names.length == 1
        ? names.single
        : '${names.sublist(0, names.length - 1).join(', ')} y ${names.last}';
    final verb = names.length == 1 ? 'tiene' : 'tienen';
    return '$joined ya no $verb vinculación contigo. $_reloaded';
  }

  static const _reloaded =
      'Actualizamos la lista: revisa la selección y vuelve a asignar.';
}
