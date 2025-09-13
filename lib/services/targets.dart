double computeDailyTarget({
  required String sex, // 'male' | 'female'
  required int age,
  required int heightCm,
  required double weightKg,
  required String goal, // lose | gain | maintain
  required double ratePerWeek, // negative for lose, positive for gain, 0 for maintain
  bool sedentary = true,
}) {
  // Mifflin-St Jeor BMR
  final bmr = (sex == 'female')
      ? (10 * weightKg + 6.25 * heightCm - 5 * age - 161)
      : (10 * weightKg + 6.25 * heightCm - 5 * age + 5);

  // Sedentary factor vs light
  final tdee = bmr * (sedentary ? 1.2 : 1.375);

  // 1kg fat ~ 7700 kcal
  final dailyAdjust = (7700.0 * ratePerWeek) / 7.0;
  final target = tdee + dailyAdjust; // negative deficit for lose
  // safety clamp
  return target.clamp(1200.0, 4500.0);
}
