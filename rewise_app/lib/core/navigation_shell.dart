import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/dashboard_screen.dart';
import '../screens/add_topic_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/all_tasks_screen.dart';
import 'design_system.dart';
import 'providers.dart';

class NavigationShell extends ConsumerStatefulWidget {
  const NavigationShell({super.key});

  @override
  ConsumerState<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends ConsumerState<NavigationShell> with WidgetsBindingObserver {
  late final PageController _pageController;
  RealtimeChannel? _topicsChannel;
  RealtimeChannel? _subjectsChannel;
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    // Initialize PageController with current provider index
    final initialIndex = ref.read(navigationProvider);
    _pageController = PageController(initialPage: initialIndex);
    
    WidgetsBinding.instance.addObserver(this);
    _checkProfile();
    _setupRealtimeSubscriptions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _topicsChannel?.unsubscribe();
    _subjectsChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh data when app comes to foreground
      _refreshAllData();
    }
  }

  void _refreshAllData() {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      // Force logout to trigger the main listener redirect
      client.auth.signOut().catchError((_) {});
      return;
    }
    ref.read(todaysTopicsProvider.notifier).loadTopics();
    ref.invalidate(allTopicsProvider);
    ref.invalidate(subjectsProvider);
    ref.invalidate(userProfileProvider);
  }

  void _setupRealtimeSubscriptions() {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    _topicsChannel = client
        .channel('topics_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'topics',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            ref.read(todaysTopicsProvider.notifier).loadTopics();
            ref.invalidate(allTopicsProvider);
          },
        )
        .subscribe();

    _subjectsChannel = client
        .channel('subjects_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'subjects',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            ref.invalidate(subjectsProvider);
          },
        )
        .subscribe();
  }

  Future<void> _checkProfile() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select()
          .eq('user_id', session.user.id)
          .maybeSingle();

      if (mounted) {
        if (response == null || response['name'] == null) {
          Navigator.of(context).pushReplacementNamed('/onboarding');
        }
      }
    } catch (e) {
      // Ignore errors here, let them see dashboard if it fails
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationProvider);

    // Sync PageController if provider changed externally
    if (_pageController.hasClients && _pageController.page?.round() != currentIndex) {
      _pageController.animateToPage(
        currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // If not on first tab, go to first tab instead of exiting
        if (currentIndex != 0) {
          ref.read(navigationProvider.notifier).state = 0;
          _pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          return;
        }
        // Double-tap back to exit
        final now = DateTime.now();
        if (_lastBackPress != null && now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          Navigator.of(context).pop();
          return;
        }
        _lastBackPress = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            ref.read(navigationProvider.notifier).state = index;
          },
          children: const [
            DashboardScreen(),
            AnalyticsScreen(),
            AllTasksScreen(),
            AddTopicScreen(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1), width: 0.5)),
          ),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (index) {
              ref.read(navigationProvider.notifier).state = index;
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            backgroundColor: Theme.of(context).colorScheme.surface,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textSecondary,
            type: BottomNavigationBarType.fixed,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Dashboard'),
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Analytics'),
              BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'All Topics'),
              BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline_rounded), label: 'Add Topic'),
            ],
          ),
        ),
      ),
    );
  }
}
