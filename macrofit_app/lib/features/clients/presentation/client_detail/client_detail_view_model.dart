import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/client_summary.dart';
import '../../domain/repositories/clients_repository.dart';

/// HU-24 — detalle de un cliente con acceso a sus metas y comidas.
///
/// Empieza con el resumen que trae la lista; [refresh] lo vuelve a pedir
/// (p. ej. al regresar de fijarle una meta).
class ClientDetailViewModel extends ViewModel {
  ClientDetailViewModel({required this._repository, required this._client});

  final ClientsRepository _repository;

  ClientSummary _client;
  bool _isUnlinked = false;
  bool _isRefreshing = false;
  String? _error;

  ClientSummary get client => _client;

  /// El cliente ya no aparece entre los vinculados (se desvinculó, HU-14).
  bool get isUnlinked => _isUnlinked;
  bool get isRefreshing => _isRefreshing;
  String? get error => _error;

  Future<void> refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    _error = null;
    notifyListeners();
    try {
      final clients = await _repository.getClients();
      final current = clients.where((client) => client.id == _client.id);
      if (current.isEmpty) {
        _isUnlinked = true;
      } else {
        _client = current.first;
        _isUnlinked = false;
      }
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }
}
