import 'dart:math';

enum MemoryRating {
  forgot(2),
  hard(3),
  medium(4),
  easy(5);

  final int value;
  const MemoryRating(this.value);
}

class SpacedRepetitionEngine {
  /// Default Ease Factor for new topics
  static const double defaultEaseFactor = 2.5;

  /// Calculate the updated Ease Factor based on the rating
  static double calculateNewEaseFactor(double currentEaseFactor, MemoryRating rating) {
    if (rating == MemoryRating.forgot) {
      // Typically the ease factor drops significantly, but let's apply the exact formula
      // provided in the architecture spec.
    }
    
    // Formula: EF = EF + (0.1 - (5 - rating) * (0.08 + (5 - rating) * 0.02))
    int r = rating.value;
    double adjustment = 0.1 - (5 - r) * (0.08 + (5 - r) * 0.02);
    
    double newEf = currentEaseFactor + adjustment;
    // It's a best practice to ensure EF doesn't drop below 1.3
    if (newEf < 1.3) newEf = 1.3;
    
    return newEf;
  }

  /// Calculate the updated Stability based on the rating utilizing static multipliers
  static double calculateNewStability(double currentStability, MemoryRating rating) {
    const multipliers = {
      MemoryRating.forgot: 0.5,
      MemoryRating.hard: 1.2,
      MemoryRating.medium: 1.8,
      MemoryRating.easy: 2.5,
    };
    
    // Safety check enforcing >0 boundary guarantees math resolves seamlessly for new cards or complete failures
    double baseStability = currentStability > 0 ? currentStability : 1.0;
    double newStability = baseStability * multipliers[rating]!;
    // Minimum stability floor prevents aggressive 1-day loops from chains of "Forgot"
    if (newStability < 0.5) newStability = 0.5;
    return newStability;
  }

  /// Calculate the new interval dynamically bounded by a target retention metric
  /// Formula derived via `Retention = exp(-interval / Stability)` -> `interval = -Stability * ln(Retention)`
  static int calculateNewInterval(double newStability, {double targetRetention = 0.85}) {
    double exactInterval = -newStability * log(targetRetention);
    return max(1, exactInterval.round()); // Interval should never drop below absolute 1-day floor
  }

  /// Calculate retention percentage based on stability and time elapsed
  /// Formula: Retention = e^(-t / Stability)
  static double calculateRetention(double daysSinceReview, double stability) {
    if (stability <= 0) return 0.0;
    double retention = exp(-daysSinceReview / stability);
    return retention;
  }

  /// Calculates Priority Score: (100 - Retention) + Overdue Days * 5 + Weakness Weight
  static double calculatePriorityScore({
    required double retention,
    required int overdueDays,
    double weaknessWeight = 0.0,
    double difficultyModifier = 1.0,
  }) {
    double retentionPercentage = retention * 100;
    double score = (100 - retentionPercentage) + (overdueDays * 5) + weaknessWeight;
    return score * difficultyModifier;
  }
}
