import 'dart:math';
import 'package:flutter/material.dart';

import '../app_data.dart';
import '../services/learning_stats_service.dart';
import '../services/tts_service.dart';

class FlashcardScreen extends StatefulWidget {
  final List<VocabItem> words;
  final bool isMyanmar;

  const FlashcardScreen({
    super.key,
    required this.words,
    required this.isMyanmar,
  });

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen>
    with SingleTickerProviderStateMixin {
  late final List<VocabItem> _queue;
  int _currentIndex = 0;
  int _masteredCount = 0;
  int _againCount = 0;
  bool _isCompleted = false;

  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _queue = List<VocabItem>.from(widget.words);
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    )..addListener(() {
        if (_flipAnimation.value >= 0.5 && !_showBack) {
          setState(() => _showBack = true);
        } else if (_flipAnimation.value < 0.5 && _showBack) {
          setState(() => _showBack = false);
        }
      });
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_flipController.isAnimating) return;
    if (_flipController.isCompleted) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
  }

  void _handleReview(String level) {
    if (_currentIndex >= _queue.length) return;
    final currentWord = _queue[_currentIndex];

    if (level == 'easy') {
      _masteredCount++;
    } else if (level == 'again') {
      _againCount++;
      // Re-queue to study again in this session
      _queue.add(currentWord);
    }
    LearningStatsService.recordSrsReview(currentWord.paliRoman, level);

    if (_currentIndex + 1 >= _queue.length) {
      setState(() {
        _isCompleted = true;
      });
    } else {
      if (_flipController.isCompleted) {
        _flipController.reset();
        _showBack = false;
      }
      setState(() {
        _currentIndex++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMm = widget.isMyanmar;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isMm ? 'Flashcard အလွတ်ကျက်' : 'Flashcards'),
        ),
        body: Center(
          child: Text(isMm ? 'လေ့လာရန် စကားလုံးမရှိပါ' : 'No words to study'),
        ),
      );
    }

    if (_isCompleted) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isMm ? 'Flashcard ပြီးဆုံးပါပြီ' : 'Flashcards Complete'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.stars_rounded,
                  size: 72,
                  color: colors.secondary,
                ),
                const SizedBox(height: 16),
                Text(
                  isMm ? 'ကျက်မှတ်မှု ပြီးမြောက်ပါပြီ' : 'Study Session Complete',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isMm
                      ? 'ရပြီးသော စကားလုံး: $_masteredCount ခု\nထပ်ကျက်ခဲ့သော အကြိမ်: $_againCount ကြိမ်'
                      : 'Mastered: $_masteredCount\nReviewed again: $_againCount times',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _queue
                            ..clear()
                            ..addAll(widget.words);
                          _currentIndex = 0;
                          _masteredCount = 0;
                          _againCount = 0;
                          _isCompleted = false;
                          _flipController.reset();
                          _showBack = false;
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(isMm ? 'ပြန်စမည်' : 'Restart'),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(isMm ? 'ပြီးပါပြီ' : 'Done'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentWord = _queue[_currentIndex];
    final progress = (_currentIndex + 1) / _queue.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(isMm ? 'Flashcard အလွတ်ကျက်' : 'Flashcards'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isMm
                            ? 'ကတ်ပြား ${_currentIndex + 1} / ${_queue.length}'
                            : 'CARD ${_currentIndex + 1} OF ${_queue.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                      Text(
                        isMm ? 'ကတ်ကိုနှိပ်၍ လှန်ပါ' : 'Tap card to flip',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: GestureDetector(
                  onTap: _flipCard,
                  child: AnimatedBuilder(
                    animation: _flipAnimation,
                    builder: (context, child) {
                      final angle = _flipAnimation.value * pi;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle),
                        child: _showBack
                            ? Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(pi),
                                child: _buildBackCard(context, currentWord, isMm),
                              )
                            : _buildFrontCard(context, currentWord, isMm),
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.error,
                        side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _handleReview('again'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.replay_rounded, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            isMm ? 'ထပ်ကျက်မည်' : 'Again',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.secondary,
                        side: BorderSide(
                          color: colors.secondary.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _handleReview('hard'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.help_outline_rounded, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            isMm ? 'ခက်သည်' : 'Hard',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _handleReview('easy'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 20),
                          const SizedBox(height: 4),
                          Text(
                            isMm ? 'ရပြီ' : 'Easy',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrontCard(BuildContext context, VocabItem word, bool isMm) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              colors.surface,
              colors.surfaceContainerLow,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isMm ? 'ပါဠိစကားလုံး' : 'PĀḶI WORD',
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const Spacer(),
            Text(
              isMm ? word.paliMm : word.paliRoman,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.primary,
                fontSize: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isMm ? word.paliRoman : word.paliMm,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            const Spacer(),
            IconButton.filledTonal(
              tooltip: isMm ? 'အသံနားထောင်ရန်' : 'Listen',
              iconSize: 28,
              icon: const Icon(Icons.volume_up_rounded),
              onPressed: () => TtsService.speakPali(word.paliRoman),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  isMm ? 'အဓိပ္ပာယ် ကြည့်ရန် နှိပ်ပါ' : 'Tap to reveal meaning',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackCard(BuildContext context, VocabItem word, bool isMm) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              colors.surfaceContainerLowest,
              colors.surface,
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      isMm ? 'အဓိပ္ပာယ်' : 'MEANING',
                      style: TextStyle(
                        color: colors.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: isMm ? 'အသံနားထောင်ရန်' : 'Listen',
                    icon: const Icon(Icons.volume_up_rounded),
                    onPressed: () => TtsService.speakPali(word.paliRoman),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                isMm ? word.paliMm : word.paliRoman,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isMm ? word.translateMm : word.translateEn,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isMm ? word.translateEn : word.translateMm,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (word.example != null) ...[
                const Divider(height: 32),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isMm ? 'သာဓက ဝါကျ —' : 'Example sentence —',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMm
                                ? word.example!.paliMm
                                : word.example!.paliRoman,
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isMm
                                ? word.example!.translateMm
                                : word.example!.translateEn,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isMm
                          ? 'သာဓက အသံနားထောင်ရန်'
                          : 'Listen to example',
                      icon: const Icon(Icons.volume_up_rounded, size: 20),
                      onPressed: () =>
                          TtsService.speakPali(word.example!.paliRoman),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
