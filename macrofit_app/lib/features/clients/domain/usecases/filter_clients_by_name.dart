import '../entities/client_summary.dart';

/// Clientes cuyo nombre contiene [query], sin distinguir mayúsculas ni acentos.
/// Filtra en memoria la lista ya cargada: no hace otra petición a la API.
List<ClientSummary> filterClientsByName(
  List<ClientSummary> clients,
  String query,
) {
  final normalizedQuery = normalizeForSearch(query.trim());
  if (normalizedQuery.isEmpty) return clients;
  return [
    for (final client in clients)
      if (normalizeForSearch(client.name).contains(normalizedQuery)) client,
  ];
}

const _withoutAccents = {
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};

/// Minúsculas y sin acentos (`José Núñez` → `jose nunez`).
String normalizeForSearch(String text) => text
    .toLowerCase()
    .split('')
    .map((char) => _withoutAccents[char] ?? char)
    .join();
