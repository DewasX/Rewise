import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/design_system.dart';
import '../core/topic_service.dart';
import '../core/providers.dart';
import '../core/responsive_wrapper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddTopicScreen extends ConsumerStatefulWidget {
  const AddTopicScreen({super.key});

  @override
  ConsumerState<AddTopicScreen> createState() => _AddTopicScreenState();
}

class _AddTopicScreenState extends ConsumerState<AddTopicScreen> {
  final _topicService = TopicService();
  final _topicNameController = TextEditingController();

  String? selectedSubject;
  int? selectedTime;
  String selectedDifficulty = 'Medium';
  bool _isSaving = false;
  List<String> subjects = [];
  bool _isLoadingSubjects = true;

  final List<String> _defaultSubjects = [
    'Mathematics', 'Physics', 'Chemistry', 'Biology',
    'History', 'Literature', 'Computer Science', 'Economics'
  ];

  final List<int> studyTimes = [10, 15, 20, 25, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          subjects = List.from(_defaultSubjects);
          _isLoadingSubjects = false;
        });
        return;
      }

      final response = await client
          .from('subjects')
          .select('name')
          .eq('user_id', userId);

      final dbSubjects = (response as List).map((s) => s['name'] as String).toList();

      // Merge defaults + database subjects (no duplicates)
      final merged = <String>{..._defaultSubjects, ...dbSubjects}.toList();

      if (mounted) {
        setState(() {
          subjects = merged;
          _isLoadingSubjects = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          subjects = List.from(_defaultSubjects);
          _isLoadingSubjects = false;
        });
      }
    }
  }

  void _showCustomSubjectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text('Add Custom Subject', style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Subject name',
              hintStyle: TextStyle(color: Theme.of(context).hintColor),
            ),
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
            textCapitalization: TextCapitalization.words,
            maxLength: 50,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isNotEmpty && !subjects.contains(name)) {
                  setState(() {
                    subjects.add(name);
                    selectedSubject = name;
                  });
                } else if (subjects.contains(name)) {
                  setState(() => selectedSubject = name);
                }
                Navigator.pop(context);
              },
              child: const Text('Add', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _topicNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final topicName = _topicNameController.text.trim();
    
    // Per-field validation
    if (selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a subject'), backgroundColor: AppColors.urgent),
      );
      return;
    }
    if (topicName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a topic name'), backgroundColor: AppColors.urgent),
      );
      return;
    }
    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a study time'), backgroundColor: AppColors.urgent),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      int difficultyMap = 3;
      if (selectedDifficulty == 'Easy') difficultyMap = 1;
      if (selectedDifficulty == 'Hard') difficultyMap = 5;

      await _topicService.insertTopic(
        name: topicName,
        subjectName: selectedSubject!,
        estimatedMinutes: selectedTime!,
        difficulty: difficultyMap,
      );

      // Refresh today's topics in Dashboard
      ref.read(todaysTopicsProvider.notifier).loadTopics();
      ref.invalidate(allTopicsProvider);
      ref.invalidate(subjectsProvider);

      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          // If used as a tab, switch back to dashboard
          ref.read(navigationProvider.notifier).state = 0;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Failed to save topic. Please try again.'), backgroundColor: AppColors.urgent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color, size: 20),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  ref.read(navigationProvider.notifier).state = 0;
                }
              },
            ),
          ),
        ),
        title: Text('Add Topic', style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color, fontWeight: FontWeight.bold)),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 1000;
          return ResponsiveWrapper(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isDesktop ? 32.0 : AppDesign.padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Subject', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            ...subjects.map((s) {
                              final isCustom = !_defaultSubjects.contains(s);
                              return _buildPill(
                                context,
                                s, 
                                selectedSubject == s, 
                                () => setState(() => selectedSubject = s),
                                onDelete: isCustom ? () => _confirmDeleteSubject(s) : null,
                              );
                            }),
                            _buildPill(context, '+ Custom', false, _showCustomSubjectDialog, isAction: true),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Text('Topic Name', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _topicNameController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Integration by Parts',
                            hintStyle: TextStyle(color: Theme.of(context).hintColor),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          ),
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                          textCapitalization: TextCapitalization.words,
                          maxLength: 100,
                        ),
                        const SizedBox(height: 32),
                        Text('Estimated Study Time', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: studyTimes.map((t) => _buildPill(context, '${t}m', selectedTime == t, () => setState(() => selectedTime = t))).toList(),
                        ),
                        const SizedBox(height: 32),
                        Text('Difficulty', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildDifficultyCard(context, 'Easy', 'Quick review', selectedDifficulty == 'Easy', AppColors.strong)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildDifficultyCard(context, 'Medium', 'Moderate effort', selectedDifficulty == 'Medium', AppColors.fading)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildDifficultyCard(context, 'Hard', 'Deep focus', selectedDifficulty == 'Hard', AppColors.urgent)),
                          ],
                        ),
                        const SizedBox(height: 32), // Reduced from 48 since button is now at the bottom
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 32.0 : AppDesign.padding,
                    0,
                    isDesktop ? 32.0 : AppDesign.padding,
                    isDesktop ? 32.0 : AppDesign.padding + MediaQuery.of(context).padding.bottom,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B2D45), // Dark reddish from screenshot
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        disabledBackgroundColor: const Color(0xFF6B2D45).withValues(alpha: 0.5),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary, strokeWidth: 2))
                          : const Text('Add to Study Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPill(BuildContext context, String label, bool isSelected, VoidCallback onTap, {bool isAction = false, VoidCallback? onDelete}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : (isAction ? Colors.transparent : Theme.of(context).colorScheme.surface),
          border: isAction ? Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.transparent) : (isSelected ? null : Border.all(color: Colors.transparent)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.w500)),
            if (onDelete != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDelete,
                child: Icon(Icons.close, size: 16, color: isSelected ? Colors.white70 : AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSubject(String subjectName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Delete Subject', style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color)),
        content: Text('Are you sure you want to delete "$subjectName"?', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
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
        await ref.read(topicServiceProvider).deleteSubject(subjectName);
        
        setState(() {
          subjects.remove(subjectName);
          if (selectedSubject == subjectName) selectedSubject = null;
        });

        // Invalidate subject provider broadly
        ref.invalidate(subjectsProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
               backgroundColor: AppColors.urgent,
               duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Widget _buildDifficultyCard(BuildContext context, String title, String subtitle, bool isSelected, Color color) {
    return GestureDetector(
      onTap: () => setState(() => selectedDifficulty = title),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : Colors.transparent),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: isSelected ? color : Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
