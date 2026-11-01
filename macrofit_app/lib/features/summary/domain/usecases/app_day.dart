/// Zona horaria con la que el backend define el día (`APP_UTC_OFFSET`, México por defecto).
const appUtcOffset = Duration(hours: -6);

/// Día `YYYY-MM-DD` de [now] en la zona horaria de la app, el mismo criterio del backend.
String appDay(DateTime now) {
  final local = now.toUtc().add(appUtcOffset);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-${two(local.day)}';
}
