import 'dart:convert';
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
      'theme': prefs.getString(_themeKey) ?? 'system',
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

  /// Deletes all user data rows from all tables, then signs out.
  /// Note: Hard auth-user deletion requires a server-side Edge Function.
  Future<void> deleteAllUserData(String userId) async {
    final client = Supabase.instance.client;
    await client.from('review_history').delete().eq('user_id', userId);
    await client.from('topics').delete().eq('user_id', userId);
    await client.from('subjects').delete().eq('user_id', userId);
    await client.from('users').delete().eq('user_id', userId);
  }
}

final settingsServiceProvider = Provider<SettingsService>((ref) => SettingsService());
