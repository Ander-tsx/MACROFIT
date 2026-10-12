enum Gender { male, female }

enum FitnessObjective { loseFat, maintain, gainMuscle }

class UserProfile {
  final String userId;
  final double weightKg;
  final double heightCm;
  final DateTime birthDate;
  final Gender gender;
  final int trainingDaysPerWeek;
  final FitnessObjective objective;

  const UserProfile({
    required this.userId,
    required this.weightKg,
    required this.heightCm,
    required this.birthDate,
    required this.gender,
    required this.trainingDaysPerWeek,
    required this.objective,
  });

  int ageAt(DateTime now) {
    var age = now.year - birthDate.year;
    final hadBirthday =
        now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthday) age--;
    return age;
  }
}
