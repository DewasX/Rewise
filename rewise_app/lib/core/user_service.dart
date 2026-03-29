import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>?> getUserProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('users')
          .select()
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
      return response;
    } catch (e) {
      return null;
    }
  }

  String sanitizeName(String name) {
    // Collapse multiple spaces and trim, allowing international characters and symbols
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> createUserProfile(String name) async {
    final sanitizedName = sanitizeName(name);
    final userId = _client.auth.currentUser?.id;
    final email = _client.auth.currentUser?.email;
    if (userId == null) throw Exception('Your session has expired. Please sign in again.');

    await _client.from('users').upsert({
      'user_id': userId,
      'name': sanitizedName,
      'email': email,
    }).timeout(const Duration(seconds: 15));
  }

  Future<void> updateName(String name) async {
    final sanitizedName = sanitizeName(name);
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Your session has expired. Please sign in again.');
    await _client.from('users').update({'name': sanitizedName}).eq('user_id', userId).timeout(const Duration(seconds: 15));
  }

  Future<int> getReviewsCompletedToday() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    try {
      // Midnight today (local time)
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toUtc().toIso8601String();

      final response = await _client
          .from('review_history')
          .select('id')
          .eq('user_id', userId)
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay)
          .timeout(const Duration(seconds: 15));
      
      return (response as List).length;
    } catch (e) {
      return 0; // Fallback to 0 if offline or error
    }
  }
}
