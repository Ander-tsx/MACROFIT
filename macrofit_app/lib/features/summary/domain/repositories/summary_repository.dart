import '../entities/day_summary.dart';
import '../entities/week_summary.dart';

abstract class SummaryRepository {
  /// HU-10 — resumen del día `date` (`YYYY-MM-DD`).
  Future<DaySummary> getDaily(String date);

  /// HU-11 — resumen de los 7 días desde `start` (`YYYY-MM-DD`).
  Future<WeekSummary> getWeekly(String start);
}
