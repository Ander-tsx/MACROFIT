import 'dart:typed_data';

import '../../domain/entities/client_meal.dart';
import '../../domain/entities/client_summary.dart';
import '../../domain/repositories/clients_repository.dart';
import '../datasources/clients_remote_data_source.dart';

class ClientsRepositoryImpl implements ClientsRepository {
  const ClientsRepositoryImpl(this._remote);

  final ClientsRemoteDataSource _remote;

  @override
  Future<List<ClientSummary>> getClients() => _remote.getClients();

  @override
  Future<List<ClientMeal>> getClientMeals(String clientId, DateTime date) =>
      _remote.getClientMeals(clientId, date);

  @override
  Future<Uint8List> getMealPhoto(String photoUrl) =>
      _remote.getMealPhoto(photoUrl);
}
