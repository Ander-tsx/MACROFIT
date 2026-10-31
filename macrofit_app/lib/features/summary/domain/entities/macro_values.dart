/// Calorías, proteína y grasa de un día (consumo, meta o restante).
class MacroValues {
  const MacroValues({
    required this.caloriesKcal,
    required this.proteinG,
    required this.fatG,
  });

  final double caloriesKcal;
  final double proteinG;
  final double fatG;
}
