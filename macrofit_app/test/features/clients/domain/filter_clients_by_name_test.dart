import 'package:flutter_test/flutter_test.dart';
import 'package:macrofit_app/features/clients/domain/entities/client_summary.dart';
import 'package:macrofit_app/features/clients/domain/usecases/filter_clients_by_name.dart';

ClientSummary _client(String name) =>
    ClientSummary(id: name, name: name, email: '$name@macrofit.test');

void main() {
  final clients = [
    _client('Ana López'),
    _client('José Pérez'),
    _client('Mariana Núñez'),
  ];

  List<String> names(List<ClientSummary> result) => [
    for (final client in result) client.name,
  ];

  test('sin texto de búsqueda devuelve a todos en el mismo orden', () {
    expect(names(filterClientsByName(clients, '')), [
      'Ana López',
      'José Pérez',
      'Mariana Núñez',
    ]);
    expect(filterClientsByName(clients, '   '), hasLength(3));
  });

  test('no distingue mayúsculas de minúsculas', () {
    expect(names(filterClientsByName(clients, 'ANA')), [
      'Ana López',
      'Mariana Núñez',
    ]);
  });

  test('no distingue acentos en el nombre ni en la búsqueda', () {
    expect(names(filterClientsByName(clients, 'jose')), ['José Pérez']);
    expect(names(filterClientsByName(clients, 'lÓpez')), ['Ana López']);
    expect(names(filterClientsByName(clients, 'nunez')), ['Mariana Núñez']);
  });

  test('ignora los espacios al inicio y al final', () {
    expect(names(filterClientsByName(clients, '  perez ')), ['José Pérez']);
  });

  test('sin coincidencias devuelve una lista vacía', () {
    expect(filterClientsByName(clients, 'Carlos'), isEmpty);
  });
}
