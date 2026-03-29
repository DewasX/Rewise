import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://eytnitbiqbusvudbetyv.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV5dG5pdGJpcWJ1c3Z1ZGJldHl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI1NjcyMDEsImV4cCI6MjA4ODE0MzIwMX0.RuwHMl31zv5ptsNEpQyC4DlDlSDeBXQDRxDZdBd_4x0';

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
