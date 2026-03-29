import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers.dart';
import 'offline_sync_service.dart';

class SettingsService {
  static const _themeKey = 'pref_theme';

  // ── Preferences ──────────────────────────────────────────────────────────────

  Future<Map<String, String>> getPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'theme': prefs.getString(_themeKey) ?? 'dark',
    };
  }

  Future<void> savePreference(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> setTheme(String value) => savePreference(_themeKey, value);

  // ── Export ───────────────────────────────────────────────────────────────────

  /// Fetches all user data and returns a JSON string ready for export.
  Future<String> exportData(String userId) async {
    final client = Supabase.instance.client;

    final topics = await client.from('topics').select().eq('user_id', userId);
    final subjects = await client.from('subjects').select().eq('user_id', userId);
    final reviews = await client.from('review_history').select().eq('user_id', userId);

    final export = {
      'exported_at': DateTime.now().toIso8601String(),
      'topics': topics,
      'subjects': subjects,
      'reviews': reviews,
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(export);
  }

  // ── Delete Account ───────────────────────────────────────────────────────────

  /// Deletes all user data rows from all tables, then the auth user.
  /// Hard auth-user deletion is handled securely via a Postgres RPC function.
  Future<void> deleteAllUserData() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    // Step 1: Always delete all public data rows first (order matters for FK constraints)
    try {
      await client.from('review_history').delete().eq('user_id', userId);
    } catch (_) {}
    try {
      await client.from('topics').delete().eq('user_id', userId);
    } catch (_) {}
    try {
      await client.from('subjects').delete().eq('user_id', userId);
    } catch (_) {}
    try {
      await client.from('daily_plan').delete().eq('user_id', userId);
    } catch (_) {}
    try {
      await client.from('users').delete().eq('user_id', userId);
    } catch (_) {}

    // Step 2: Attempt to delete the auth.users entry via RPC (requires SECURITY DEFINER)
    try {
      await client.rpc('delete_user');
    } catch (e) {
      debugPrint('RPC delete_user failed (auth user may persist): $e');
    }
  }
}

final settingsServiceProvider = Provider<SettingsService>((ref) => SettingsService());
