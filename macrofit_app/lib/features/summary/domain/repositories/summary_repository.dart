import '../entities/day_summary.dart';

abstract class SummaryRepository {
  /// HU-10 — resumen del día `date` (`YYYY-MM-DD`).
  Future<DaySummary> getDaily(String date);
}
