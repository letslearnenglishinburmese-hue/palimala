import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../app_data.dart';
import '../services/learning_stats_service.dart';
import '../services/tts_service.dart';

class _QuizQuestion {
  final VocabItem question;
  final List<VocabItem> choices;
  final int answerPosition;

  const _QuizQuestion({
    required this.question,
    required this.choices,
    required this.answerPosition,
  });
}

class VocabularyQuizScreen extends StatefulWidget {
  final List<VocabItem> words;
  final bool isMyanmar;
  final Random? random;
  final bool isListeningMode;

  const VocabularyQuizScreen({
    super.key,
    required this.words,
    required this.isMyanmar,
    this.random,
    this.isListeningMode = false,
  });

  @override
  State<VocabularyQuizScreen> createState() => _VocabularyQuizScreenState();
}

class _VocabularyQuizScreenState extends State<VocabularyQuizScreen> {
  int _questionIndex = 0;
  int _score = 0;
  int? _selectedIndex;
  late final List<_QuizQuestion> _questions;

  @override
  void initState() {
    super.initState();
    _questions = _buildQuestions();
    if (widget.isListeningMode && _questions.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(TtsService.speakPali(_questions[0].question.paliRoman));
      });
    }
  }

  List<_QuizQuestion> _buildQuestions() {
    final totalQuestions = widget.words.length < 10 ? widget.words.length : 10;
    if (totalQuestions == 0) return const [];
    final random = widget.random ?? Random();
    final questions = <_QuizQuestion>[];
    final isMm = widget.isMyanmar;

    for (var i = 0; i < totalQuestions; i++) {
      final currentWord = widget.words[i];
      final currentMeaning =
          isMm ? currentWord.translateMm : currentWord.translateEn;
      final distractors = widget.words.where((w) {
        final meaning = isMm ? w.translateMm : w.translateEn;
        return meaning != currentMeaning;
      }).toList()..shuffle(random);

      final seenMeanings = <String>{currentMeaning};
      final uniqueDistractors = <VocabItem>[];
      for (final distractor in distractors) {
        final meaning = isMm ? distractor.translateMm : distractor.translateEn;
        if (seenMeanings.add(meaning)) {
          uniqueDistractors.add(distractor);
          if (uniqueDistractors.length >= 3) break;
        }
      }

      final choices = [currentWord, ...uniqueDistractors]..shuffle(random);
      final answerPosition = choices.indexOf(currentWord);

      questions.add(
        _QuizQuestion(
          question: currentWord,
          choices: choices,
          answerPosition: answerPosition,
        ),
      );
    }
    return questions;
  }

  void _selectAnswer(int index) {
    if (_selectedIndex != null || _questionIndex >= _questions.length) return;
    setState(() {
      _selectedIndex = index;
      if (index == _questions[_questionIndex].answerPosition) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      _questionIndex++;
      _selectedIndex = null;
      if (_questionIndex >= _questions.length) {
        LearningStatsService.recordQuizResult(
          total: _questions.length,
          correct: _score,
        );
      } else if (widget.isListeningMode) {
        unawaited(
          TtsService.speakPali(_questions[_questionIndex].question.paliRoman),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMm = widget.isMyanmar;
    final totalQuestions = _questions.length;
    final completed = _questionIndex >= totalQuestions;
    final currentQ = completed ? null : _questions[_questionIndex];
    final question = currentQ?.question;
    final choices = currentQ?.choices ?? const <VocabItem>[];
    final answerPosition = currentQ?.answerPosition ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isListeningMode
              ? (isMm ? 'အသံနားထောင် လေ့ကျင့်ခန်း' : 'Listening Quiz')
              : (isMm ? 'အခန်းလေ့ကျင့်ခန်း' : 'Chapter Practice'),
        ),
      ),
      body: completed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isMm ? 'လေ့ကျင့်မှု ပြီးဆုံးပါပြီ' : 'Practice complete',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isMm
                          ? 'အဖြေမှန် $_score / $totalQuestions ခု'
                          : '$_score of $totalQuestions correct',
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(isMm ? 'ပြီးပါပြီ' : 'Done'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                LinearProgressIndicator(
                  value: (_questionIndex + 1) / totalQuestions,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 12),
                Text(
                  isMm
                      ? 'မေးခွန်း ${_questionIndex + 1} / $totalQuestions'
                      : 'QUESTION ${_questionIndex + 1} OF $totalQuestions',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 24),
                if (widget.isListeningMode) ...[
                  Center(
                    child: FilledButton.tonalIcon(
                      onPressed: () =>
                          TtsService.speakPali(question!.paliRoman),
                      icon: const Icon(Icons.volume_up_rounded, size: 28),
                      label: Text(
                        isMm ? 'အသံနားထောင်ရန်' : 'Listen to Pāḷi',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  if (_selectedIndex != null) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        isMm ? question!.paliMm : question!.paliRoman,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ] else
                  Text(
                    isMm ? question!.paliMm : question!.paliRoman,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  widget.isListeningMode
                      ? (isMm
                            ? 'အသံကို နားထောင်ပြီး မှန်ကန်သော အဓိပ္ပာယ်ကို ရွေးပါ'
                            : 'Listen and choose the correct meaning')
                      : (isMm
                            ? 'မှန်ကန်သော အဓိပ္ပာယ်ကို ရွေးပါ'
                            : 'Choose the correct meaning'),
                ),
                const SizedBox(height: 16),
                for (var index = 0; index < choices.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OutlinedButton(
                      onPressed: () => _selectAnswer(index),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        backgroundColor: _selectedIndex == null
                            ? null
                            : index == answerPosition
                            ? Colors.green.withValues(alpha: 0.14)
                            : index == _selectedIndex
                            ? Theme.of(context).colorScheme.errorContainer
                            : null,
                      ),
                      child: Text(
                        isMm
                            ? choices[index].translateMm
                            : choices[index].translateEn,
                      ),
                    ),
                  ),
                if (_selectedIndex != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _selectedIndex == answerPosition
                        ? (isMm ? 'အဖြေမှန်ပါသည်' : 'Correct answer')
                        : (isMm
                              ? 'အဖြေမှန်: ${question!.translateMm}'
                              : 'Correct: ${question!.translateEn}'),
                    style: TextStyle(
                      color: _selectedIndex == answerPosition
                          ? Colors.green.shade700
                          : Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _nextQuestion,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(isMm ? 'နောက်မေးခွန်း' : 'Next question'),
                  ),
                ],
              ],
            ),
    );
  }
}
