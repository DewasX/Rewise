import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/topic.dart';
import '../core/design_system.dart';
import '../core/providers.dart';
import '../core/offline_sync_service.dart';
import 'study_session_screen.dart';
import '../core/responsive_wrapper.dart';
import 'account_settings_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsState = ref.watch(todaysTopicsProvider);
    final notifier = ref.read(todaysTopicsProvider.notifier);
    final userProfile = ref.watch(userProfileProvider);
    final subjectsState = ref.watch(subjectsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 1000;
            return ResponsiveWrapper(
              child: topicsState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Warning: $err', style: const TextStyle(color: AppColors.urgent)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(todaysTopicsProvider.notifier).loadTopics(),
                        child: const Text('Retry / Load Mock Data'),
                      )
                    ],
                  ),
                ),
                data: (topics) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 32.0 : AppDesign.padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context, ref, userProfile),
                        SizedBox(height: isDesktop ? 40 : 24),
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildMemoryOverview(context, topics)),
                              const SizedBox(width: 24),
                              Expanded(child: _buildGoalAndProgress(context, notifier.completedToday, notifier.dailyGoal, notifier.progress)),
                            ],
                          )
                        else ...[
                          _buildMemoryOverview(context, topics),
                          const SizedBox(height: 16),
                          _buildGoalAndProgress(context, notifier.completedToday, notifier.dailyGoal, notifier.progress),
                        ],
                        SizedBox(height: isDesktop ? 48 : 32),
                        _buildPlanHeader(context),
                        const SizedBox(height: 16),
                        if (topics.isEmpty)
                          _buildEmptyState(context)
                        else ...[
                           // Group topics by subject for consistency
                          () {
                            final groupedTopics = <String, List<Topic>>{};
                            for (var topic in topics) {
                              groupedTopics.putIfAbsent(topic.subjectId, () => []).add(topic);
                            }

                            final subjects = subjectsState.value ?? [];
                            final activeSubjects = subjects.where((s) => groupedTopics.containsKey(s['id'])).toList();

                            return Column(
                              children: activeSubjects.map((subject) {
                                final subjectName = subject['name'] ?? 'Unknown Subject';
                                final subjectTopics = groupedTopics[subject['id']] ?? [];

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8, bottom: 12),
                                      child: Row(
                                        children: [
                                          Text(
                                            subjectName.toUpperCase(),
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Container(
                                              height: 1,
                                              color: Theme.of(context).dividerTheme.color ?? Colors.transparent,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ...subjectTopics.map((topic) => _buildTopicCard(context, ref, topic, subjectName)),
                                    const SizedBox(height: 16),
                                  ],
                                );
                              }).toList(),
                            );
                          }(),
                        ],
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, AsyncValue<Map<String, dynamic>?> userProfile) {
    String greeting = 'Hello';
    final hour = DateTime.now().hour;
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    final userName = userProfile.value?['name'] ?? '';

    final nextReviewText = _getFormattedDate();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nextReviewText,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 4),
              Text('$greeting${userName.isNotEmpty ? ' $userName' : ''} 👋',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.headlineMedium?.color,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                  softWrap: true,
                  maxLines: 2),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flash_on, color: AppColors.accent, size: 16),
                const SizedBox(width: 4),
                Text('${userProfile.value?['streak_count'] ?? 0} day streak',
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
          ),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDesign.radius),
        border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.transparent),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.strong, size: 48),
          const SizedBox(height: 16),
          Text("All caught up!", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("You've completed all your reviews for today. Great job!", 
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMemoryOverview(BuildContext context, List<Topic> topics) {
    double overallMemory = 0.0;
    if (topics.isNotEmpty) {
      double total = topics.fold(0.0, (sum, t) => sum + t.currentMemoryScore);
      overallMemory = total / topics.length;
    }

    int strongCount = topics.where((t) => t.status == 'Strong').length;
    int fadingCount = topics.where((t) => t.status == 'Fading').length;
    int urgentCount = topics.where((t) => t.status == 'Urgent').length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDesign.radius),
        border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.transparent),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 110,
                width: 110,
                child: CircularProgressIndicator(
                  value: overallMemory > 0 ? overallMemory / 100.0 : 0.0,
                  strokeWidth: 10,
                  backgroundColor: Theme.of(context).dividerTheme.color?.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.fading),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${overallMemory.toInt()}%',
                      style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const Text('Memory',
                      style:
                          TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                  const Text('New',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              children: [
                _buildStatusRow(context, 'Strong', '$strongCount', AppColors.strong, Icons.verified_user_outlined),
                const SizedBox(height: 12),
                _buildStatusRow(context, 'Fading', '$fadingCount', AppColors.fading, Icons.bolt_outlined),
                const SizedBox(height: 12),
                _buildStatusRow(context, 'Urgent', '$urgentCount', AppColors.urgent, Icons.fireplace_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(BuildContext context, String label, String count, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 13)),
        const Spacer(),
        Text(count,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildGoalAndProgress(BuildContext context, int completed, int dailyGoal, double progress) {
    // If completed >= goal, show a special message
    final isGoalMet = completed >= dailyGoal && dailyGoal > 0;

    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
            context: context,
            icon: Icons.access_time,
            label: 'Daily Goal',
            value: isGoalMet ? 'Completed 🎉' : '$dailyGoal',
            subValue: isGoalMet ? 'Great job today!' : '${dailyGoal - completed} reviews remaining', 
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildInfoCard(
            context: context,
            icon: Icons.psychology_outlined,
            label: "Today's Progress",
            value: '$completed / $dailyGoal',
            isProgress: true,
            progressValue: progress,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    String? subValue,
    bool isProgress = false,
    double progressValue = 0.0,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDesign.radius),
        border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 16),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          if (subValue != null) ...[
            const SizedBox(height: 4),
            Text(subValue,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
          ],
          if (isProgress) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 4,
                backgroundColor: Theme.of(context).dividerTheme.color?.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE91E63)), // Pinkish
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Today's Plan",
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        TextButton.icon(
          onPressed: () {
            Navigator.pushNamed(context, '/add-topic');
          },
          icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
          label: const Text('Add Topic',
              style: TextStyle(color: AppColors.primary, fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildTopicCard(BuildContext context, WidgetRef ref, Topic topic, String subjectName) {
    Color statusColor = topic.status == 'Urgent' ? AppColors.urgent : AppColors.fading;
    IconData statusIcon = topic.status == 'Urgent' ? Icons.fireplace : Icons.bolt;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StudySessionScreen(topic: topic, subjectName: subjectName),
          ),
        );
      },
      borderRadius: BorderRadius.circular(AppDesign.radius),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDesign.radius),
          border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.transparent),
        ),
        child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 52,
                width: 52,
                child: CircularProgressIndicator(
                  value: topic.currentMemoryScore / 100.0,
                  strokeWidth: 4,
                  backgroundColor: Theme.of(context).dividerTheme.color?.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              Text('${topic.currentMemoryScore.toInt()}',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.topicName,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subjectName,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, color: AppColors.textSecondary, size: 12),
                    const SizedBox(width: 4),
                    Text('${topic.estimatedMinutes}m',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(width: 8),
                    Icon(Icons.circle, size: 4, color: Theme.of(context).dividerTheme.color),
                    const SizedBox(width: 8),
                    Text('Today', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 10),
                    const SizedBox(width: 4),
                    Text(topic.status,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Icon(Icons.chevron_right, color: Theme.of(context).dividerTheme.color, size: 24),
            ],
          ),
        ],
      ),
    ));
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }
}
