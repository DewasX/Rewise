import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://eytnitbiqbusvudbetyv.supabase.co';
  static const String anonKey = 'sb_publishable_ZyTHAolO-RUBUOFNs-saBw_0lmW2SKr';

  static Future<void> initialize() async {
    if (url == 'YOUR_SUPABASE_URL' || anonKey == 'YOUR_SUPABASE_ANON_KEY') {
      debugPrint('Warning: Supabase keys not set. Running in Mock mode.');
      return;
    }
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  static SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}
