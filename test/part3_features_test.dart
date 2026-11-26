import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimala/app_data.dart';
import 'package:palimala/main.dart';
import 'package:palimala/pali_transliteration.dart';
import 'package:palimala/widgets/word_share_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (call) async => 1,
        );
  });

  group('Diacritic-insensitive Search Normalization', () {
    test('normalizes Romanized Pali diacritics accurately', () {
      expect(normalizePaliSearch('Mettā'), 'metta');
      expect(normalizePaliSearch('Nibbānaṃ'), 'nibbanam');
      expect(normalizePaliSearch('Saṅgha'), 'sangha');
      expect(normalizePaliSearch('Paññā'), 'panna');
      expect(normalizePaliSearch('Ṭhānaṃ'), 'thanam');
      expect(normalizePaliSearch('Daḷha'), 'dalha');
    });
  });

  group('Time-based SRS, Daily Goal & Badges', () {
    test('recordSrsReview schedules intervals 1 -> 3 -> 7 -> 14 and due keys', () async {
      final day0 = DateTime(2026, 11, 26);

      // 1st easy review -> +1 day
      final s1 = await LearningStatsService.recordSrsReview('mettā', 'easy', now: day0);
      expect(s1.intervalDays, 1);
      expect(s1.repetitions, 1);
      expect(s1.nextReviewDate, '2026-11-27');

      // Not due on day0
      var dueDay0 = await LearningStatsService.getDueWordKeys(now: day0);
      expect(dueDay0, isNot(contains('mettā')));

      // Due on day1
      final day1 = DateTime(2026, 11, 27);
      var dueDay1 = await LearningStatsService.getDueWordKeys(now: day1);
      expect(dueDay1, contains('mettā'));

      // 2nd easy review -> +3 days
      final s2 = await LearningStatsService.recordSrsReview('mettā', 'easy', now: day1);
      expect(s2.intervalDays, 3);
      expect(s2.repetitions, 2);
      expect(s2.nextReviewDate, '2026-11-30');

      // 3rd easy review -> +7 days
      final day4 = DateTime(2026, 11, 30);
      final s3 = await LearningStatsService.recordSrsReview('mettā', 'easy', now: day4);
      expect(s3.intervalDays, 7);
      expect(s3.repetitions, 3);

      // 'again' resets interval to 0 (due immediately)
      final sAgain = await LearningStatsService.recordSrsReview('mettā', 'again', now: day4);
      expect(sAgain.intervalDays, 0);
      expect(sAgain.repetitions, 0);
      expect(sAgain.nextReviewDate, '2026-11-30');
    });

    test('daily goal progress and achievement badges unlock properly', () async {
      await LearningStatsService.setDailyGoal(5);
      await LearningStatsService.recordQuizResult(total: 10, correct: 9);

      final stats = await LearningStatsService.getStats();
      expect(stats.dailyGoal, 5);
      expect(stats.todayWordsCount, 10);
      expect(stats.dailyGoalProgress, 1.0);

      final firstStep = stats.badges.firstWhere((b) => b.id == 'first_step');
      final quizAce = stats.badges.firstWhere((b) => b.id == 'quiz_ace');
      final streak7 = stats.badges.firstWhere((b) => b.id == 'streak_7');
      expect(firstStep.unlocked, isTrue);
      expect(quizAce.unlocked, isTrue);
      expect(streak7.unlocked, isFalse);
    });
  });

  group('Listening Quiz & Audio UX', () {
    final words = [
      VocabItem(
        paliMm: 'ဗုဒ္ဓ',
        paliRoman: 'buddha',
        translateMm: 'မြတ်စွာဘုရား',
        translateEn: 'The Enlightened One',
      ),
      VocabItem(
        paliMm: 'ဓမ္မ',
        paliRoman: 'dhamma',
        translateMm: 'တရားတော်',
        translateEn: 'The Dhamma',
      ),
    ];

    testWidgets('Listening Quiz hides Pali text until an answer is selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VocabularyQuizScreen(
            words: words,
            isMyanmar: true,
            isListeningMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('အသံနားထောင် လေ့ကျင့်ခန်း'), findsOneWidget);
      expect(find.text('အသံနားထောင်ရန်'), findsOneWidget);

      // Pali word should be hidden before answering
      expect(find.text('ဗုဒ္ဓ'), findsNothing);
      expect(find.text('ဓမ္မ'), findsNothing);

      // Tap first answer choice
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pumpAndSettle();

      // Pali word is revealed after answering
      expect(
        find.text('ဗုဒ္ဓ').evaluate().length +
            find.text('ဓမ္မ').evaluate().length,
        1,
      );
    });

    test('TtsService.isSpeaking updates on speakPali and stop', () async {
      await TtsService.speakPali('buddha');
      expect(TtsService.isSpeaking.value, isTrue);
      await TtsService.stop();
      expect(TtsService.isSpeaking.value, isFalse);
    });
  });

  group('WordShareDialog Image Share & Pali Bank Branding', () {
    testWidgets('shows Share as Image button and Pali Bank branding', (
      tester,
    ) async {
      final word = VocabItem(
        paliMm: 'သတိ',
        paliRoman: 'sati',
        translateMm: 'သတိတရား',
        translateEn: 'Mindfulness',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WordShareDialog(word: word, isMyanmar: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pali Bank · နေ့စဉ်ဝေါဟာရ'), findsOneWidget);
      expect(find.text('Pali Bank'), findsOneWidget);
      expect(find.text('ပုံရိပ်အဖြစ် မျှဝေမည်'), findsOneWidget);
    });
  });
}
