import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/topic.dart';
import 'topic_service.dart';
import 'spaced_repetition_engine.dart';
import 'supabase_config.dart';
import 'settings_service.dart';
import 'package:flutter/material.dart';
import 'user_service.dart';

// Global theme mode provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

final navigationProvider = StateProvider<int>((ref) => 0);

// Provider for the TopicService
final topicServiceProvider = Provider<TopicService>((ref) {
  return TopicService();
});

// Provider for fetching all topics
final allTopicsProvider = FutureProvider<List<Topic>>((ref) async {
  final service = ref.watch(topicServiceProvider);
  return await service.getAllTopics();
});

// Provider for User Profile
final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final client = SupabaseConfig.client;
  final userId = client?.auth.currentUser?.id;
  if (client == null || userId == null) return null;

  try {
    return await client.from('users').select().eq('user_id', userId).maybeSingle();
  } catch (e) {
    return null;
  }
});

// Provider for User's Subjects
final subjectsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = SupabaseConfig.client;
  final userId = client?.auth.currentUser?.id;
  if (client == null || userId == null) return [];

  try {
    return await client.from('subjects').select().eq('user_id', userId);
  } catch (e) {
    return [];
  }
});

// StateNotifier to manage the list of today's topics and their UI state
class TodaysTopicsNotifier extends StateNotifier<AsyncValue<List<Topic>>> {
  final TopicService _topicService;
  final UserService _userService; // Added dependency for real stats
  int _completedToday = 0;
  int _dailyGoal = 10; // Default fallback if not loaded from profile
  int _totalToday = 0;

  TodaysTopicsNotifier(this._topicService, this._userService) : super(const AsyncValue.loading()) {
    loadTopics();
  }

  int get completedToday => _completedToday;
  int get dailyGoal => _dailyGoal;
  double get progress => _dailyGoal == 0 ? 0.0 : (_completedToday / _dailyGoal).clamp(0.0, 1.0);
  int get totalToday => _totalToday;

  Future<void> loadTopics() async {
    state = const AsyncValue.loading();
    try {
      final topics = await _topicService.getTodaysTopics();
      _totalToday = topics.length;

      // Real query for progress
      _completedToday = await _userService.getReviewsCompletedToday();
      
      // Attempt to load daily_goal from profile if it exists, otherwise default 10
      final profile = await _userService.getUserProfile();
      if (profile != null && profile.containsKey('daily_goal')) {
        _dailyGoal = profile['daily_goal'] ?? 10;
      }

      state = AsyncValue.data(topics);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> reviewTopic(Topic topic, MemoryRating rating) async {
    // Optimistically remove from list immediately for snappy UI
    if (state.hasValue) {
      final currentTopics = state.value!;
      final updatedList = currentTopics.where((t) => t.id != topic.id).toList();
      _completedToday++;
      state = AsyncValue.data(updatedList);
    }

    try {
      await _topicService.recordReview(topic, rating);
      // Reload actual count from DB to correct any drift from failed reviews
      _completedToday = await _userService.getReviewsCompletedToday();
    } catch (e) {
      // Optimistic update accepted — if backend fails, offline sync will retry
    }
  }

  Future<void> skipTopic(Topic topic) async {
    // Optimistically remove from list immediately for snappy UI
    if (state.hasValue) {
      final currentTopics = state.value!;
      final updatedList = currentTopics.where((t) => t.id != topic.id).toList();
      state = AsyncValue.data(updatedList);
    }

    try {
      await _topicService.skipTopic(topic);
    } catch (e) {
      // Optimistic update accepted
    }
  }
}

// Global provider for the topics state
final todaysTopicsProvider = StateNotifierProvider<TodaysTopicsNotifier, AsyncValue<List<Topic>>>((ref) {
  final service = ref.watch(topicServiceProvider);
  final userService = UserService();
  return TodaysTopicsNotifier(service, userService);
});
