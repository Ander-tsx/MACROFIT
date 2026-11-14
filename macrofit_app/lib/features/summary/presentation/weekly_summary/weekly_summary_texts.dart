import '../../domain/usecases/app_day.dart';

const _weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// `lun`, `mar`… del día `YYYY-MM-DD`.
String weekdayShort(String day) => _weekdays[weekdayOf(day) - 1];

/// `16 oct` del día `YYYY-MM-DD`.
String dayMonth(String day) =>
    '${dayOfMonth(day)} ${_months[monthOf(day) - 1]}';

/// Rango de la semana: `16 oct – 22 oct`.
String weekRange(String start, String end) =>
    '${dayMonth(start)} – ${dayMonth(end)}';

/// Número sin decimales sobrantes: `70` y `35.5`.
String number(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);
