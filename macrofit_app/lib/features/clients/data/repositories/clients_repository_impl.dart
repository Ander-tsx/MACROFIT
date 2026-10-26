import '../../domain/entities/client_summary.dart';
import '../../domain/repositories/clients_repository.dart';
import '../datasources/clients_remote_data_source.dart';

class ClientsRepositoryImpl implements ClientsRepository {
  const ClientsRepositoryImpl(this._remote);

  final ClientsRemoteDataSource _remote;

  @override
  Future<List<ClientSummary>> getClients() => _remote.getClients();
}
