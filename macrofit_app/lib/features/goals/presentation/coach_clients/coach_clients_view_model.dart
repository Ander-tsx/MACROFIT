import '../../../../core/errors/api_exception.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/coach_client.dart';
import '../../domain/repositories/coach_goals_repository.dart';

/// HU-05 — lista mínima de clientes vinculados para elegir a quién fijarle una meta.
class CoachClientsViewModel extends ViewModel {
  CoachClientsViewModel(this._repository);

  final CoachGoalsRepository _repository;

  List<CoachClient> _clients = const [];
  bool _isLoading = false;
  String? _error;

  List<CoachClient> get clients => _clients;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _clients = await _repository.getClients();
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
