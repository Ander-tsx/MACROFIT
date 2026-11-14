import '../../../summary/domain/usecases/app_day.dart';

/// Tamaño del periodo de las gráficas de progreso (RF-18).
enum ProgressRange { week, month }

/// Periodo de las gráficas: una semana (7 días seguidos, como el resumen semanal
/// de HU-11) o un mes de calendario. Nunca termina después de hoy.
class ProgressPeriod {
  const ProgressPeriod._(this.range, this.from, this.to);

  /// Periodo que incluye [today] (`YYYY-MM-DD`): la semana que termina hoy o el
  /// mes en curso hasta hoy.
  factory ProgressPeriod.current(
    ProgressRange range,
    String today,
  ) => switch (range) {
    ProgressRange.week => ProgressPeriod._(range, shiftDay(today, -6), today),
    ProgressRange.month => ProgressPeriod._(range, _firstOfMonth(today), today),
  };

  final ProgressRange range;

  /// Primer y último día, `YYYY-MM-DD`.
  final String from;
  final String to;

  /// El periodo anterior completo.
  ProgressPeriod previous() => switch (range) {
    ProgressRange.week => ProgressPeriod._(
      range,
      shiftDay(from, -7),
      shiftDay(from, -1),
    ),
    ProgressRange.month => _month(shiftDay(from, -1)),
  };

  /// ¿Hay un periodo siguiente que no empiece en el futuro?
  bool canGoForward(String today) => shiftDay(to, 1).compareTo(today) <= 0;

  /// El periodo siguiente, recortado a [today]. Sin periodo siguiente devuelve
  /// el mismo.
  ProgressPeriod next(String today) {
    if (!canGoForward(today)) return this;
    final start = shiftDay(to, 1);
    return switch (range) {
      ProgressRange.week => ProgressPeriod._(
        range,
        start,
        _min(shiftDay(start, 6), today),
      ),
      ProgressRange.month => _month(start, cap: today),
    };
  }

  /// Días del periodo.
  int get length => _daysBetween(from, to) + 1;

  @override
  bool operator ==(Object other) =>
      other is ProgressPeriod &&
      other.range == range &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(range, from, to);

  @override
  String toString() => 'ProgressPeriod(${range.name}, $from, $to)';
}

/// Mes de calendario que contiene [day], recortado a [cap] si se indica.
ProgressPeriod _month(String day, {String? cap}) {
  final first = _firstOfMonth(day);
  final last = shiftDay(_firstOfMonth(shiftDay(first, 31)), -1);
  return ProgressPeriod._(
    ProgressRange.month,
    first,
    cap == null ? last : _min(last, cap),
  );
}

String _firstOfMonth(String day) => '${day.substring(0, 8)}01';

String _min(String a, String b) => a.compareTo(b) <= 0 ? a : b;

int _daysBetween(String a, String b) =>
    DateTime.parse('${b}T00:00:00Z')
        .difference(DateTime.parse('${a}T00:00:00Z'))
        .inDays;
