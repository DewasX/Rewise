import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../models/topic.dart';
import 'spaced_repetition_engine.dart';
import 'supabase_config.dart';
import 'notification_service.dart';
import 'offline_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TopicService {
  SupabaseClient? get _client => SupabaseConfig.client;

  Future<void> insertTopic({
    required String name,
    required String subjectName,
    required int estimatedMinutes,
    required int difficulty,
  }) async {
    final client = _client;
    if (client == null) throw Exception('Unable to connect to the server. Please try again later.');
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Your session has expired. Please sign in again.');

    // Handle Subject relationship seamlessly
    String? finalSubjectId;
    final existingSubject = await client
        .from('subjects')
        .select('id') 
        .eq('user_id', userId)
        .eq('name', subjectName)
        .maybeSingle();

    if (existingSubject != null) {
      finalSubjectId = existingSubject['id'];
    } else {
      final insertedSubject = await client.from('subjects').insert({
        'user_id': userId,
        'name': subjectName,
      }).select().single();
      finalSubjectId = insertedSubject['id'];
    }

    await client.from('topics').insert({
      'user_id': userId,
      'subject_id': finalSubjectId,
      'name': name,
      'estimated_minutes': estimatedMinutes,
      'difficulty': difficulty,
    });
  }

  Future<List<Topic>> getTodaysTopics() async {
    final client = _client;
    final prefs = await SharedPreferences.getInstance();
    
    // Attempt background sync of any previously offline queued reviews
    OfflineSyncService().syncPendingReviews().catchError((_) {});

    if (client == null) throw Exception('Unable to connect to the server. Please try again later.');
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Your session has expired. Please sign in again.');

    try {
      final String today = DateTime.now().toIso8601String().split('T')[0];
      final response = await client
          .from('topics')
          .select()
          .eq('user_id', userId)
          .or('next_review_date.lte.$today,next_review_date.is.null'); // Topics that are strictly due today or new
      
      final topics = (response as List).map((json) => Topic.fromJson(json)).toList();
      topics.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
      
      // Cache for offline mode
      await prefs.setString('cached_todays_topics', jsonEncode(topics.map((t) => t.toJson()).toList()));
      
      return topics;
    } catch (e) {
      // Fallback to offline cache
      final cachedString = prefs.getString('cached_todays_topics');
      if (cachedString != null) {
        final List<dynamic> decoded = jsonDecode(cachedString);
        final offlineTopics = decoded.map((json) => Topic.fromJson(json)).toList();
        offlineTopics.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
        return offlineTopics;
      }
      throw Exception('Unable to load your topics. Please check your connection and try again.');
    }
  }

  Future<List<Topic>> getAllTopics() async {
    final client = _client;
    if (client == null) throw Exception('Unable to connect to the server. Please try again later.');
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Your session has expired. Please sign in again.');

    try {
      final response = await client
          .from('topics')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      return (response as List).map((json) => Topic.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Unable to load your topics. Please check your connection and try again.');
    }
  }

  Future<void> recordReview(Topic topic, MemoryRating rating) async {
    final client = _client;
    if (client == null) throw Exception('Unable to connect to the server. Please try again later.');

    // Get current user, or fallback (will fail RLS if not logged in)
    final userId = client.auth.currentUser?.id ?? topic.userId;

    final newEf = SpacedRepetitionEngine.calculateNewEaseFactor(topic.easeFactor, rating);
    final newStability = SpacedRepetitionEngine.calculateNewStability(topic.stabilityValue, rating);
    final newInterval = SpacedRepetitionEngine.calculateNewInterval(newStability);
    final nextReview = DateTime.now().add(Duration(days: newInterval));
    
    try {
      final exactReviewTime = DateTime.now();
      
      // Update Topic to Supabase DB.
      // Utilize conditional .lte flag to prevent older offline reviews from overwriting fresh web reviews
      final String safeFallbackDate = topic.lastReviewedAt?.toIso8601String() ?? '1970-01-01T00:00:00.000';
      
      await client.from('topics').update({
        'ease_factor': newEf,
        'interval_days': newInterval,
        'stability': newStability, 
        'memory_score': 100.0,
        'last_reviewed_at': exactReviewTime.toIso8601String(),
        'next_review_date': nextReview.toIso8601String().split('T')[0],
        'repetition_count': topic.repetitionCount + 1,
      }).eq('id', topic.id).or('last_reviewed_at.lte.$safeFallbackDate,last_reviewed_at.is.null');

      // Add to history
      await client.from('review_history').insert({
        'topic_id': topic.id,
        'user_id': userId,
        'rating': rating.value,
        'interval_before': topic.intervalDays,
        'interval_after': newInterval,
        'retention_before': topic.currentMemoryScore / 100.0,
        'retention_after': 1.0, 
        // Explicitly inject timestamp so delayed offline syncs log against correct daily goals
        'created_at': exactReviewTime.toUtc().toIso8601String(),
      });
    } catch (e) {
      // Network drop -> fallback to OfflineQueue
      await OfflineSyncService().queueReview(topic, rating);
    }

    // Schedule notification for the new review date
    // We fetch it mapped because we only have the partial new info
    final updatedTopic = Topic(
      id: topic.id,
      userId: userId,
      subjectId: topic.subjectId,
      topicName: topic.topicName,
      difficultyLevel: topic.difficultyLevel,
      createdAt: topic.createdAt,
      easeFactor: newEf,
      intervalDays: newInterval,
      nextReviewDate: nextReview,
    );
    NotificationService().scheduleReviewNotification(updatedTopic);
  }

  Future<void> deleteTopic(String topicId) async {
    final client = _client;
    if (client == null) throw Exception('Unable to connect to the server. Please try again later.');
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Your session has expired. Please sign in again.');

    try {
      // Delete review history strictly tied to this topic (handled by Supabase constraints or explicitly here)
      await client.from('review_history').delete().eq('topic_id', topicId);

      // Delete the topic itself safely ensuring user permissions
      await client.from('topics').delete().eq('id', topicId).eq('user_id', userId);
    } catch (e) {
      throw Exception('Unable to delete topic. Please try again.');
    }
  }

  Future<void> deleteSubject(String subjectName) async {
    final client = _client;
    if (client == null) throw Exception('Unable to connect to the server. Please try again later.');
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Your session has expired. Please sign in again.');

    try {
      // Find exact subject ID
      final existingSubject = await client
          .from('subjects')
          .select('id')
          .eq('user_id', userId)
          .eq('name', subjectName)
          .maybeSingle();

      if (existingSubject == null) return;
      final subjectId = existingSubject['id'];

      // Must ensure no topics are currently dependent on this subject
      final existingTopics = await client
          .from('topics')
          .select('id')
          .eq('subject_id', subjectId)
          .count(CountOption.exact);

      if (existingTopics.count > 0) {
        throw Exception('Cannot delete subject. This subject contains topics. Delete the topics first or move them to another subject.');
      }

      await client.from('subjects').delete().eq('id', subjectId).eq('user_id', userId);
    } on Exception catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', '')); // Propagate the specific warning message
    } catch (e) {
      throw Exception('Unable to delete custom subject. Please try again.');
    }
  }
}
