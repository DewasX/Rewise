import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design_system.dart';
import '../core/providers.dart';
import '../core/responsive_wrapper.dart';
import 'subject_topics_screen.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(todaysTopicsProvider.notifier);
    final allTopicsState = ref.watch(allTopicsProvider);
    final subjectsState = ref.watch(subjectsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 1000;
            return ResponsiveWrapper(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isDesktop ? 32.0 : AppDesign.padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Memory Analytics',
                        style: TextStyle(color: Theme.of(context).textTheme.headlineMedium?.color, fontSize: isDesktop ? 32 : 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: isDesktop ? 8 : 4),
                    Text('Track your memory strength over time',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: isDesktop ? 16 : 13)),
                    allTopicsState.when(
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator())),
                      error: (e, st) => const Center(child: Text('Error loading topics', style: TextStyle(color: AppColors.urgent))),
                      data: (topics) {
                        return Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             SizedBox(height: isDesktop ? 40 : 24),
                             _buildOverallScore(context, notifier.completedToday, topics),
                             SizedBox(height: isDesktop ? 24 : 16),
                             _buildTrendCard(context),
                             SizedBox(height: isDesktop ? 24 : 16),
                             _buildSubjectBreakdown(context, topics, subjectsState.value),
                           ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOverallScore(BuildContext context, int completedToday, List<dynamic> topics) {
    double overallScore = 0.0;
    if (topics.isNotEmpty) {
      final totalScore = topics.fold(0.0, (sum, t) => sum + (t.currentMemoryScore as num));
      overallScore = totalScore / topics.length;
    }

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
                height: 100,
                width: 100,
                child: CircularProgressIndicator(
                  value: overallScore / 100.0,
                  strokeWidth: 8,
                  backgroundColor: Theme.of(context).dividerTheme.color?.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.fading),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${overallScore.toInt()}%',
                      style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Overall', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Topics', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.topic, color: AppColors.primary, size: 20),
                    const SizedBox(width: 4),
                    Text('${topics.length}',
                        style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Text('in your study plan', style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                const SizedBox(height: 12),
                const Text('Completed Today', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Text('$completedToday', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDesign.radius),
        border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Memory Trend',
              style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const SizedBox(
            height: 120,
            child: Center(
              child: Text(
                'Review more topics to see your weekly trend',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((d) => Text(d, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectBreakdown(BuildContext context, List<dynamic> topics, List<Map<String, dynamic>>? subjects) {
    if (subjects == null || subjects.isEmpty || topics.isEmpty) {
      return const SizedBox.shrink(); // Empty state
    }

    // Group topics by subject directly
    final Map<String, List<dynamic>> grouped = {};
    for (var topic in topics) {
      grouped.putIfAbsent(topic.subjectId, () => []).add(topic);
    }

    // Convert to a list of widgets sorting by topic count
    final items = grouped.entries.map((entry) {
       final subId = entry.key;
       final subjectTopics = entry.value;
       
       final subjectName = subjects.firstWhere(
         (s) => s['id'] == subId,
         orElse: () => {'name': 'Unknown'}
       )['name'];

       final count = subjectTopics.length;
       final avgScore = subjectTopics.fold(0.0, (sum, t) => sum + (t.currentMemoryScore as num)) / count;
       final color = avgScore > 75 ? AppColors.strong : (avgScore < 40 ? AppColors.urgent : AppColors.fading);

       return GestureDetector(
         onTap: () {
           Navigator.of(context).push(
             MaterialPageRoute(
               builder: (context) => SubjectTopicsScreen(
                 subjectId: subId,
                 subjectName: subjectName,
               ),
             ),
           );
         },
         child: Padding(
           padding: const EdgeInsets.only(bottom: 16.0),
           child: _buildBreakdownItem(context, subjectName, '$count topics', avgScore / 100.0, color),
         ),
       );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDesign.radius),
        border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Subject Breakdown',
              style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ...items,
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(BuildContext context, String label, String count, double value, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13)),
            Row(
              children: [
                Text(count, style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                const SizedBox(width: 8),
                Text('${(value * 100).toInt()}%',
                    style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: Theme.of(context).dividerTheme.color?.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
