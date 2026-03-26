import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/topic.dart';
import 'spaced_repetition_engine.dart';
import 'supabase_config.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  final _pendingReviewsKey = 'offline_pending_reviews';

  Future<void> queueReview(Topic topic, MemoryRating rating) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> pending = prefs.getStringList(_pendingReviewsKey) ?? [];
    
    final reviewData = {
      'topic_id': topic.id,
      'rating': rating.value,
      'ease_factor': topic.easeFactor,
      'stability': topic.stabilityValue,
      'repetition_count': topic.repetitionCount,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    pending.add(jsonEncode(reviewData));
    await prefs.setStringList(_pendingReviewsKey, pending);
  }

  Future<void> syncPendingReviews() async {
    final client = SupabaseConfig.client;
    if (client == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final List<String> pending = prefs.getStringList(_pendingReviewsKey) ?? [];
    
    if (pending.isEmpty) return;
    
    List<String> failedTries = [];
    
    for (String item in pending) {
      try {
        final data = jsonDecode(item);
        final topicId = data['topic_id'];
        final ratingValue = data['rating'];
        final MemoryRating rating = MemoryRating.values.firstWhere((e) => e.value == ratingValue);
        final oldEf = data['ease_factor'];
        final oldStability = data['stability'] ?? 1.0; 
        final repCount = data['repetition_count'];
        final timestamp = data['timestamp'];

        final newEf = SpacedRepetitionEngine.calculateNewEaseFactor(oldEf, rating);
        final newStability = SpacedRepetitionEngine.calculateNewStability(oldStability, rating);
        final newInterval = SpacedRepetitionEngine.calculateNewInterval(newStability);
        final exactReviewTime = DateTime.parse(timestamp);
        final nextReview = exactReviewTime.add(Duration(days: newInterval));
        
        final String safeFallbackDate = timestamp;

        await client.from('topics').update({
          'ease_factor': newEf,
          'interval_days': newInterval,
          'stability': newStability, 
          'memory_score': 100.0,
          'last_reviewed_at': timestamp,
          'next_review_date': nextReview.toIso8601String().split('T')[0],
          'repetition_count': repCount + 1,
        }).eq('id', topicId).or('last_reviewed_at.lte.$safeFallbackDate,last_reviewed_at.is.null');

        // Dedup check: skip insert if a review with the same topic+timestamp already exists
        final existing = await client
            .from('review_history')
            .select('id')
            .eq('topic_id', topicId)
            .eq('created_at', exactReviewTime.toUtc().toIso8601String())
            .maybeSingle();

        if (existing == null) {
          await client.from('review_history').insert({
            'topic_id': topicId,
            'user_id': client.auth.currentUser?.id,
            'rating': ratingValue,
            'interval_before': data['interval_days'] ?? 1,
            'interval_after': newInterval,
            'retention_before': 0.0,
            'retention_after': 1.0,
            'created_at': exactReviewTime.toUtc().toIso8601String(),
          });
        }
      } catch (e) {
        failedTries.add(item); // Keep in queue if sync fails
      }
    }
    
    await prefs.setStringList(_pendingReviewsKey, failedTries);
  }
}
