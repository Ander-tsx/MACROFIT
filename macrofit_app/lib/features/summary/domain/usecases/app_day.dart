/// Zona horaria con la que el backend define el día (`APP_UTC_OFFSET`, México por defecto).
const appUtcOffset = Duration(hours: -6);

/// Día `YYYY-MM-DD` de [now] en la zona horaria de la app, el mismo criterio del backend.
String appDay(DateTime now) => _format(now.toUtc().add(appUtcOffset));

/// [day] (`YYYY-MM-DD`) desplazado [days] días (negativo = hacia atrás).
String shiftDay(String day, int days) =>
    _format(_parse(day).add(Duration(days: days)));

/// Día de la semana de [day]: 1 = lunes … 7 = domingo.
int weekdayOf(String day) => _parse(day).weekday;

/// Día del mes de [day].
int dayOfMonth(String day) => _parse(day).day;

/// Mes de [day]: 1 = enero … 12 = diciembre.
int monthOf(String day) => _parse(day).month;

DateTime _parse(String day) => DateTime.parse('${day}T00:00:00Z');

String _format(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-${two(date.day)}';
}
