import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/supabase_config.dart';
import 'core/design_system.dart';
import 'core/providers.dart';
import 'core/navigation_shell.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/add_topic_screen.dart';
import 'core/notification_service.dart';
import 'screens/reset_password_screen.dart';
import 'dart:async';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SupabaseConfig.initialize();
  await NotificationService().init();

  // Load initial settings
  final prefs = await SharedPreferences.getInstance();
  final themeStr = prefs.getString('pref_theme') ?? 'dark';
  final initialThemeMode = themeStr == 'system' 
      ? ThemeMode.system 
      : (themeStr == 'light' ? ThemeMode.light : ThemeMode.dark);

  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((ref) => initialThemeMode),
      ],
      child: const RewiseApp(),
    ),
  );
}

class RewiseApp extends ConsumerStatefulWidget {
  const RewiseApp({super.key});

  @override
  ConsumerState<RewiseApp> createState() => _RewiseAppState();
}

class _RewiseAppState extends ConsumerState<RewiseApp> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    _checkInitialSession();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _setupAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      
      final session = data.session;
      final event = data.event;

      debugPrint('Auth Event: $event, Session: ${session != null}');

      if (event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState?.pushReplacementNamed("/reset-password");
        return;
      }

      // Handle all login/logout/initial states
      if (session != null) {
        // Logged in
        _navigateSafe("/dashboard");
      } else {
        // Not logged in
        _navigateSafe("/login");
      }
    });
  }

  void _navigateSafe(String routeName) {
    if (navigatorKey.currentState == null) return;
    
    // Only navigate if we're not already there
    final currentRoute = ModalRoute.of(navigatorKey.currentContext!)?.settings.name;
    if (currentRoute != routeName) {
      navigatorKey.currentState?.pushReplacementNamed(routeName);
    }
  }

  void _checkInitialSession() {
    // This is now handled by the listener, but we can keep a fallback 
    // in case the initial event is missed (rare with supabase_flutter)
    Future.delayed(const Duration(seconds: 2), () {
      if (navigatorKey.currentState == null) return;
      final currentRoute = ModalRoute.of(navigatorKey.currentContext!)?.settings.name;
      if (currentRoute == '/splash') {
        final session = Supabase.instance.client.auth.currentSession;
        navigatorKey.currentState?.pushReplacementNamed(session != null ? "/dashboard" : "/login");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Rewise',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(child: CircularProgressIndicator()),
            ),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const NavigationShell(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
        '/add-topic': (context) => const AddTopicScreen(),
      },
    );
  }
}
