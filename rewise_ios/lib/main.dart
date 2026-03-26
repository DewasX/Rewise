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

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SupabaseConfig.initialize();
  await NotificationService().init();

  // Load initial settings
  final prefs = await SharedPreferences.getInstance();
  final themeStr = prefs.getString('pref_theme') ?? 'system';
  final initialThemeMode = themeStr == 'dark' 
      ? ThemeMode.dark 
      : (themeStr == 'light' ? ThemeMode.light : ThemeMode.system);

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
  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    _checkInitialSession();
  }

  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      final event = data.event;

      if (event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState?.pushReplacementNamed("/reset-password");
      } else if (session != null && event == AuthChangeEvent.signedIn) {
        // User successfully authenticated
        navigatorKey.currentState?.pushReplacementNamed("/dashboard");
      } else if (event == AuthChangeEvent.signedOut) {
        navigatorKey.currentState?.pushReplacementNamed("/login");
      }
    });
  }

  void _checkInitialSession() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        navigatorKey.currentState?.pushReplacementNamed("/dashboard");
      } else {
        navigatorKey.currentState?.pushReplacementNamed("/login");
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
