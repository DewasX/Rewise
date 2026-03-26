import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../models/topic.dart';
import '../core/design_system.dart';
import '../core/providers.dart';
import '../core/topic_service.dart';
import '../core/spaced_repetition_engine.dart';
import '../core/responsive_wrapper.dart';

class StudySessionScreen extends ConsumerStatefulWidget {
  final Topic topic;
  final String subjectName;
  const StudySessionScreen({super.key, required this.topic, this.subjectName = 'Unknown'});

  @override
  ConsumerState<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends ConsumerState<StudySessionScreen> {
  final _topicService = TopicService();
  int _secondsElapsed = 0;
  Timer? _timer;
  bool _isTimerRunning = false;
  bool _isRatingPanelVisible = false;
  bool _showSuccessAnimation = false;
  int _newInterval = 0;

  @override
  void initState() {
    super.initState();
  }

  void _startTimer() {
    setState(() => _isTimerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final minutes = _secondsElapsed ~/ 60;
    final seconds = _secondsElapsed % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _handleRating(MemoryRating rating) async {
    // Calculate the new interval to display in the success overlay
    final newStability = SpacedRepetitionEngine.calculateNewStability(widget.topic.stabilityValue, rating);
    final newInterval = SpacedRepetitionEngine.calculateNewInterval(newStability);

    // 1. Trigger animation immediately for UX
    setState(() {
      _showSuccessAnimation = true;
      _isRatingPanelVisible = false;
      _newInterval = newInterval;
    });

    // 2. Perform background logic via Provider
    await ref.read(todaysTopicsProvider.notifier).reviewTopic(widget.topic, rating);

    // 2.5 Invalidate global topic lists so other screens see the freshness immediately
    ref.invalidate(allTopicsProvider);
    ref.invalidate(todaysTopicsProvider);

    // 3. Show success briefly, then pop
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 1000;
            return ResponsiveWrapper(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32.0 : 0.0),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        _buildMemoryInsightStrip(),
                        const Spacer(),
                        if (!_isRatingPanelVisible && !_showSuccessAnimation) _buildTimerDisplay(),
                        const Spacer(),
                        if (!_isRatingPanelVisible && !_showSuccessAnimation) _buildBottomActions(),
                      ],
                    ),
                    if (_isRatingPanelVisible) _buildOverlayRatingPanel(),
                    if (_showSuccessAnimation) _buildSuccessOverlay(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    Color statusColor = widget.topic.status == 'Urgent' ? AppColors.urgent : AppColors.fading;

    return Padding(
      padding: const EdgeInsets.all(AppDesign.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.topic.topicName,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.headlineMedium?.color,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Theme.of(context).iconTheme.color),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerTheme.color?.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.subjectName.toUpperCase(),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(widget.topic.status == 'Urgent' ? Icons.fireplace : Icons.bolt, color: statusColor, size: 10),
                    const SizedBox(width: 4),
                    Text(
                      widget.topic.status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, color: AppColors.textSecondary, size: 14),
                  const SizedBox(width: 4),
                  Text('${widget.topic.estimatedMinutes} min', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMemoryInsightStrip() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDesign.padding),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerTheme.color ?? Colors.transparent),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildInsightItem('Memory Strength', '${widget.topic.currentMemoryScore.toInt()}%', AppColors.primary),
          _buildInsightItem('Last reviewed', _getLastReviewedText(), Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary),
          _buildInsightItem('Reviews done', '${widget.topic.repetitionCount}', Theme.of(context).textTheme.bodyLarge?.color ?? AppColors.textPrimary),
        ],
      ),
    );
  }

  Widget _buildInsightItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      ],
    );
  }

  String _getLastReviewedText() {
    if (widget.topic.lastReviewedAt == null) {
      return 'Not reviewed yet';
    }
    final days = DateTime.now().difference(widget.topic.lastReviewedAt!).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return '1d ago';
    return '${days}d ago';
  }

  Widget _buildTimerDisplay() {
    return Column(
      children: [
        if (!_isTimerRunning && _secondsElapsed == 0)
          GestureDetector(
            onTap: _startTimer,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 28),
                  SizedBox(width: 8),
                  Text('Start Focus Timer', style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          )
        else
          Text(
            _formattedTime,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 64,
              fontWeight: FontWeight.w300,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        const SizedBox(height: 16),
        const Text('Focus Time', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.all(AppDesign.padding),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                _timer?.cancel();
                setState(() => _isRatingPanelVisible = true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Mark as Reviewed', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // Skip logic can go here
            child: const Text('Skip for today', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          )
        ],
      ),
    );
  }

  Widget _buildOverlayRatingPanel() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.all(AppDesign.padding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Before rating, try to recall key points.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 32),
          Text('How well do you remember this?', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 48),
          Column(
            children: [
              _buildLargeRatingButton('Easy', 'Perfect recall', AppColors.strong, MemoryRating.easy),
              const SizedBox(height: 16),
              _buildLargeRatingButton('Medium', 'Recalled with slight effort', AppColors.info, MemoryRating.medium),
              const SizedBox(height: 16),
              _buildLargeRatingButton('Hard', 'Struggled, but remembered', AppColors.fading, MemoryRating.hard),
              const SizedBox(height: 16),
              _buildLargeRatingButton('Forgot', 'Completely blank', AppColors.urgent, MemoryRating.forgot),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLargeRatingButton(String title, String subtitle, Color color, MemoryRating rating) {
    return InkWell(
      onTap: () => _handleRating(rating),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: AppColors.strong, size: 80),
          const SizedBox(height: 24),
          Text('Memory Strength Increased!', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Next review in $_newInterval days', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}
