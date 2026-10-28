import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/client_summary.dart';
import '../../domain/repositories/clients_repository.dart';
import '../../domain/usecases/filter_clients_by_name.dart';

/// HU-24 — lista de clientes del coach con búsqueda por nombre.
class ClientsListViewModel extends ViewModel {
  ClientsListViewModel(this._repository);

  final ClientsRepository _repository;

  List<ClientSummary> _clients = const [];
  String _query = '';
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _error;

  /// Todos los clientes vinculados, ordenados por nombre (como los manda la API).
  List<ClientSummary> get clients => _clients;

  /// Clientes que coinciden con la búsqueda.
  List<ClientSummary> get visibleClients =>
      filterClientsByName(_clients, _query);

  String get query => _query;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// La API respondió sin clientes vinculados.
  bool get hasNoClients => _hasLoaded && _clients.isEmpty;

  /// Hay clientes, pero ninguno coincide con la búsqueda.
  bool get hasNoMatches => _clients.isNotEmpty && visibleClients.isEmpty;

  /// Carga (o recarga) la lista. Si falla, conserva la última lista cargada.
  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _clients = await _repository.getClients();
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
}
