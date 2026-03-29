import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/design_system.dart';
import '../core/providers.dart';
import '../models/topic.dart';
import '../core/responsive_wrapper.dart';
import 'study_session_screen.dart';

class SubjectTopicsScreen extends ConsumerWidget {
  final String subjectId;
  final String subjectName;

  const SubjectTopicsScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTopicsState = ref.watch(allTopicsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            backgroundImage: () {
              final userMeta = Supabase.instance.client.auth.currentUser?.userMetadata;
              final avatarUrl = userMeta?['avatar_url'] ?? userMeta?['picture'];
              return avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null;
            }(),
            child: Builder(builder: (context) {
              final userMeta = Supabase.instance.client.auth.currentUser?.userMetadata;
              final avatarUrl = userMeta?['avatar_url'] ?? userMeta?['picture'];
              if (avatarUrl != null && avatarUrl.isNotEmpty) {
                 return Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                );
              }
              return IconButton(
                icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color, size: 20),
                onPressed: () => Navigator.pop(context),
              );
            }),
          ),
        ),
        title: Text(subjectName,
            style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color, fontWeight: FontWeight.bold)),
      ),
      body: allTopicsState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text('Error loading topics', style: TextStyle(color: AppColors.urgent)),
        ),
        data: (topics) {
          final filtered = topics.where((t) => t.subjectId == subjectId).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, color: Theme.of(context).dividerTheme.color, size: 48),
                  const SizedBox(height: 16),
                  const Text('No topics in this subject yet',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 1000;
              return ResponsiveWrapper(
                child: ListView.builder(
                  padding: EdgeInsets.all(isDesktop ? 32.0 : AppDesign.padding),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final topic = filtered[index];
                    return _buildTopicCard(context, topic);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTopicCard(BuildContext context, Topic topic) {
    final score = topic.currentMemoryScore;
    final statusColor = topic.status == 'Urgent'
        ? AppColors.urgent
        : (topic.status == 'Strong' ? AppColors.strong : AppColors.fading);

    String nextReviewText;
    if (topic.nextReviewDate == null) {
      nextReviewText = 'Not scheduled';
    } else {
      final diff = topic.nextReviewDate!.difference(DateTime.now()).inDays;
      if (diff <= 0) {
        nextReviewText = 'Due today';
      } else if (diff == 1) {
        nextReviewText = 'Tomorrow';
      } else {
        nextReviewText = 'In $diff days';
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StudySessionScreen(
              topic: topic,
              subjectName: subjectName,
            ),
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
              height: 56,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topic.topicName,
                      style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('Memory: ${score.toInt()}%',
                          style: TextStyle(color: statusColor, fontSize: 12)),
                      const SizedBox(width: 16),
                      Text('Next Review: $nextReviewText',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Theme.of(context).dividerTheme.color),
          ],
        ),
      ),
    );
  }
}
