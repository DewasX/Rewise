import 'dart:async';
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
  Timer? _backgroundSyncTimer;
  RealtimeChannel? _topicsChannel;
  RealtimeChannel? _subjectsChannel;

  @override
  void initState() {
    super.initState();
    // Initialize PageController with current provider index
    final initialIndex = ref.read(navigationProvider);
    _pageController = PageController(initialPage: initialIndex);
    
    WidgetsBinding.instance.addObserver(this);
    _checkProfile();
    _setupRealtimeSubscriptions();
    _startBackgroundSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _backgroundSyncTimer?.cancel();
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

  void _startBackgroundSync() {
    // Refresh from server every 5 minutes
    _backgroundSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _refreshAllData();
    });
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

    return Scaffold(
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
    );
  }
}
