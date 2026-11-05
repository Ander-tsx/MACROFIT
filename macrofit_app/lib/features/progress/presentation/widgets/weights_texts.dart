import '../../domain/entities/weight_entry.dart';

String _two(int value) => value.toString().padLeft(2, '0');

/// Fecha y hora local del registro: `05/11/2026 08:30`.
String weightDateText(DateTime recordedAt) {
  final local = recordedAt.toLocal();
  return '${_two(local.day)}/${_two(local.month)}/${local.year} '
      '${_two(local.hour)}:${_two(local.minute)}';
}

/// Sentido del cambio de peso respecto al registro anterior.
enum WeightTrend { down, up, same }

/// Diferencia contra el registro anterior (`−0.7 kg`, `+1.2 kg`, `Sin cambio`).
/// [weights] va del más reciente al más antiguo; el último no tiene anterior.
({String text, WeightTrend trend})? weightDelta(
  List<WeightEntry> weights,
  int index,
) {
  if (index + 1 >= weights.length) return null;
  final delta = weights[index].weightKg - weights[index + 1].weightKg;
  if (delta.abs() < 0.05) return (text: 'Sin cambio', trend: WeightTrend.same);
  return delta > 0
      ? (text: '+${delta.toStringAsFixed(1)} kg', trend: WeightTrend.up)
      : (text: '−${(-delta).toStringAsFixed(1)} kg', trend: WeightTrend.down);
}
