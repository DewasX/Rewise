import 'dart:math';
import '../core/spaced_repetition_engine.dart';

class Topic {
  final String id;
  final String userId;
  final String subjectId;
  final String topicName; // Maps to 'name'
  final int estimatedMinutes;
  final int difficultyLevel; // Maps to 'difficulty'
  final DateTime createdAt;
  final DateTime? lastReviewedAt;
  final DateTime? nextReviewDate;
  final int repetitionCount;
  final int intervalDays;
  final double easeFactor;
  final double stabilityValue; // Maps to 'stability'
  final double memoryScore;

  Topic({
    required this.id,
    required this.userId,
    required this.subjectId,
    required this.topicName,
    this.estimatedMinutes = 5,
    required this.difficultyLevel,
    required this.createdAt,
    this.lastReviewedAt,
    this.nextReviewDate,
    this.repetitionCount = 0,
    this.intervalDays = 1, // default 1
    this.easeFactor = 2.5,
    this.stabilityValue = 1.0,
    this.memoryScore = 50.0, // default 50
  });

  // Dynamically calculate status based on actual current memory score
  String get status {
    final score = currentMemoryScore;
    if (score < 40) return 'Urgent';
    if (score > 75) return 'Strong';
    return 'Fading';
  }

  // Calculate realtime memory score based on retention decay formula: e^(-t / Stability)
  double get currentMemoryScore {
    final referenceDate = lastReviewedAt ?? createdAt;
    final now = DateTime.now();
    final diffDays = now.difference(referenceDate).inSeconds / 86400.0;
    
    // Fallback if stability is 0 for some reason
    final stability = stabilityValue > 0 ? stabilityValue : 1.0;
    final retention = exp(-max(0, diffDays) / stability);
    return retention * 100.0;
  }

  // Calculate priority score for sorting: (100 - retention) + overdueDays * 5 + weaknessWeight
  double get priorityScore {
    final retention = currentMemoryScore / 100.0;
    // Harder topics get higher priority
    final weaknessWeight = difficultyLevel * 2.0; 
    
    // Logarithmic cap so a massive overdue deficit doesn't infinitely scale
    final overdueWeight = min(overdueDays, 30) * 5.0; 
    
    // Slight penalty to deprioritize topics failed repeatedly ("leeches")
    final leechPenalty = repetitionCount > 10 ? 5.0 : 0.0;

    return SpacedRepetitionEngine.calculatePriorityScore(
      retention: retention,
      overdueDays: overdueWeight.toInt(),
      weaknessWeight: weaknessWeight - leechPenalty,
    );
  }

  // Dynamically calculate overdue days
  int get overdueDays {
    if (nextReviewDate == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reviewDay = DateTime(nextReviewDate!.year, nextReviewDate!.month, nextReviewDate!.day);
    final diff = today.difference(reviewDay).inDays;
    return diff > 0 ? diff : 0;
  }

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      subjectId: json['subject_id'] ?? '',
      topicName: json['name'] ?? 'Untitled',
      estimatedMinutes: json['estimated_minutes'] ?? 5,
      difficultyLevel: json['difficulty'] ?? 3,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      lastReviewedAt: json['last_reviewed_at'] != null ? DateTime.parse(json['last_reviewed_at']) : null,
      nextReviewDate: json['next_review_date'] != null ? DateTime.parse(json['next_review_date']) : null,
      repetitionCount: json['repetition_count'] ?? 0,
      intervalDays: json['interval_days'] ?? 1,
      easeFactor: (json['ease_factor'] ?? 2.5).toDouble(),
      stabilityValue: (json['stability'] ?? 1.0).toDouble(),
      memoryScore: (json['memory_score'] ?? 50.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // id, user_id, subject_id typically inserted/managed separately or auto-gen
      'name': topicName,
      'subject_id': subjectId,
      'difficulty': difficultyLevel,
      'estimated_minutes': estimatedMinutes,
      'ease_factor': easeFactor,
      'interval_days': intervalDays,
      'stability': stabilityValue,
      'memory_score': memoryScore,
      'repetition_count': repetitionCount,
      'last_reviewed_at': lastReviewedAt?.toIso8601String(),
      'next_review_date': nextReviewDate?.toIso8601String().split('T')[0],
    };
  }
}
