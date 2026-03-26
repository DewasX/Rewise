import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/design_system.dart';
import '../models/topic.dart';
import '../core/providers.dart';
import '../core/responsive_wrapper.dart';
import 'study_session_screen.dart';

class AllTasksScreen extends ConsumerWidget {
  const AllTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsState = ref.watch(allTopicsProvider);
    final subjectsState = ref.watch(subjectsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('All Topics', style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color, fontWeight: FontWeight.bold)),
        iconTheme: Theme.of(context).iconTheme.copyWith(color: Theme.of(context).textTheme.titleLarge?.color),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 1000;
          return ResponsiveWrapper(
            child: topicsState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => const Center(child: Text('Error loading topics', style: TextStyle(color: AppColors.urgent))),
              data: (topics) {
                if (topics.isEmpty) {
                   return const Center(child: Text("No topics yet. Add your first topic.", style: TextStyle(color: AppColors.textSecondary)));
                }

                // Group topics by subject
                final groupedTopics = <String, List<Topic>>{};
                for (var topic in topics) {
                  groupedTopics.putIfAbsent(topic.subjectId, () => []).add(topic);
                }

                final subjects = subjectsState.value ?? [];
                // Get subjects that actually have topics to display
                final activeSubjects = subjects.where((s) => groupedTopics.containsKey(s['id'])).toList();

                return ListView.builder(
                  padding: EdgeInsets.all(isDesktop ? 32.0 : AppDesign.padding),
                  itemCount: activeSubjects.length,
                  itemBuilder: (context, index) {
                    final subject = activeSubjects[index];
                    final subjectName = subject['name'] ?? 'Unknown Subject';
                    final subjectTopics = groupedTopics[subject['id']] ?? [];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.fading.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.fading.withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  subjectName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 0.5,
                                  ),
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
                        ...subjectTopics.map((topic) => _buildSimpleTopicItem(context, ref, topic, subjectName)),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSimpleTopicItem(BuildContext context, WidgetRef ref, Topic topic, String subjectName) {
     Color statusColor = topic.status == 'Urgent' ? AppColors.urgent : AppColors.fading;

     return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StudySessionScreen(topic: topic, subjectName: subjectName),
          ),
        );
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.transparent),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.topicName, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
                Text(subjectName, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox.shrink(),
          Text('${topic.currentMemoryScore.toInt()}%', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary, size: 20),
            onPressed: () => _confirmDeleteTopic(context, ref, topic),
          ),
          Icon(Icons.chevron_right, color: Theme.of(context).dividerTheme.color),
        ],
      ),
    ),
    );
  }

  Future<void> _confirmDeleteTopic(BuildContext context, WidgetRef ref, Topic topic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Delete Topic', style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color)),
        content: Text('Are you sure you want to delete this topic?', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.urgent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(topicServiceProvider).deleteTopic(topic.id);
        
        // Refresh appropriate providers so Analytics / Dashboard / List updates immediately
        ref.invalidate(allTopicsProvider);
        ref.invalidate(todaysTopicsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Unable to delete topic. Please try again.'), backgroundColor: AppColors.urgent),
          );
        }
      }
    }
  }
}
