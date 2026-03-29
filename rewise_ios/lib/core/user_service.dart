import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('users')
          .select()
          .eq('user_id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 15));
          
      final metaName = user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? '';
      
      if (response != null) {
        if (response['name'] == null || response['name'].toString().trim().isEmpty) {
          response['name'] = metaName;
        }
        return response;
      } else {
        return {
          'user_id': user.id,
          'email': user.email,
          'name': metaName,
        };
      }
    } catch (e) {
      return {
        'user_id': user.id,
        'email': user.email,
        'name': user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? '',
      };
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

    // Clean up any orphaned profile row from a previously deleted account
    // that still holds this email (different user_id, same email).
    if (email != null && email.isNotEmpty) {
      try {
        await _client
            .from('users')
            .delete()
            .neq('user_id', userId)
            .eq('email', email)
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // Ignore — the orphan may not exist, or RLS may block it.
      }
    }

    await _client.from('users').upsert({
      'user_id': userId,
      'name': sanitizedName,
      'email': email,
    }, onConflict: 'user_id').timeout(const Duration(seconds: 15));
  }

  Future<void> updateName(String name) async {
    final sanitizedName = sanitizeName(name);
    final user = _client.auth.currentUser;
    if (user == null || user.id.isEmpty) throw Exception('Your session has expired. Please sign in again.');
    
    // Use upsert so that if the users row doesn't exist, it is created.
    // We omit 'email' to prevent unique constraint collisions if an old orphaned profile
    // holds the same email address in the database after manual account deletion.
    await _client.from('users').upsert({
      'user_id': user.id,
      'name': sanitizedName,
    }, onConflict: 'user_id').timeout(const Duration(seconds: 15));
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
