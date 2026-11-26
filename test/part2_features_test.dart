import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimala/app_data.dart';
import 'package:palimala/main.dart';
import 'package:palimala/widgets/word_share_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async => 1);
  });

  group('LearningStatsService Tests', () {
    test('initial stats are zero or defaults', () async {
      final stats = await LearningStatsService.getStats();
      expect(stats.streakDays, 0);
      expect(stats.quizTotalAnswered, 0);
      expect(stats.quizTotalCorrect, 0);
      expect(stats.quizAccuracyPercent, 0);
      expect(stats.masteredWordsCount, 0);
    });

    test('recordDailyActive increments streak properly', () async {
      await LearningStatsService.recordDailyActive();
      var stats = await LearningStatsService.getStats();
      expect(stats.streakDays, 1);

      // Calling again on the same day should maintain streak at 1
      await LearningStatsService.recordDailyActive();
      stats = await LearningStatsService.getStats();
      expect(stats.streakDays, 1);
    });

    test('recordQuizResult updates questions and accuracy', () async {
      await LearningStatsService.recordQuizResult(total: 10, correct: 8);
      var stats = await LearningStatsService.getStats();
      expect(stats.quizTotalAnswered, 10);
      expect(stats.quizTotalCorrect, 8);
      expect(stats.quizAccuracyPercent, 80);

      await LearningStatsService.recordQuizResult(total: 10, correct: 10);
      stats = await LearningStatsService.getStats();
      expect(stats.quizTotalAnswered, 20);
      expect(stats.quizTotalCorrect, 18);
      expect(stats.quizAccuracyPercent, 90);
    });

    test('markWordLearned tracks mastered words count', () async {
      await LearningStatsService.markWordLearned('dhamma', mastered: true);
      await LearningStatsService.markWordLearned('sangha', mastered: true);
      await LearningStatsService.markWordLearned('dhamma', mastered: true); // duplicate

      final stats = await LearningStatsService.getStats();
      expect(stats.masteredWordsCount, 2);
    });
  });

  group('TtsService Tests', () {
    test('setSpeechRate updates speechRate and persists', () async {
      expect(TtsService.speechRate, 0.45);
      await TtsService.setSpeechRate(0.3);
      expect(TtsService.speechRate, 0.3);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble('pali_pref_tts_rate'), 0.3);

      // Restore default
      await TtsService.setSpeechRate(0.45);
    });
  });

  group('FlashcardScreen Widget Tests', () {
    final sampleWords = [
      VocabItem(
        paliMm: 'ဗုဒ္ဓ',
        paliRoman: 'buddha',
        translateMm: 'မြတ်စွာဘုရား',
        translateEn: 'The Enlightened One',
        example: ExampleSentence(
          paliMm: 'နမော တဿ ဘဂဝတော',
          paliRoman: 'namo tassa bhagavato',
          translateMm: 'ထိုမြတ်စွာဘုရားအား ရှိခိုးပါ၏',
          translateEn: 'Homage to the Blessed One',
        ),
      ),
      VocabItem(
        paliMm: 'ဓမ္မ',
        paliRoman: 'dhamma',
        translateMm: 'တရားတော်',
        translateEn: 'The Dhamma / Teachings',
      ),
    ];

    testWidgets('renders first flashcard front and flips on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FlashcardScreen(
            words: sampleWords,
            isMyanmar: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Front card has Pali word
      expect(find.text('ဗုဒ္ဓ'), findsOneWidget);
      expect(find.text('buddha'), findsOneWidget);
      expect(find.text('မြတ်စွာဘုရား'), findsNothing);

      // Tap card to flip
      await tester.tap(find.text('ဗုဒ္ဓ'));
      await tester.pumpAndSettle();

      // Back card displays translation & example
      expect(find.text('မြတ်စွာဘုရား'), findsOneWidget);
      expect(find.text('The Enlightened One'), findsOneWidget);
      expect(find.text('နမော တဿ ဘဂဝတော'), findsOneWidget);

      // Tap "ရပြီ" to mark mastered and go to next card
      expect(find.text('ရပြီ'), findsOneWidget);
      await tester.tap(find.text('ရပြီ'));
      await tester.pumpAndSettle();

      // Second card appears
      expect(find.text('ဓမ္မ'), findsOneWidget);
    });

    testWidgets('completing cards displays completion screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FlashcardScreen(
            words: [sampleWords.first],
            isMyanmar: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Review the single card
      await tester.tap(find.text('ဗုဒ္ဓ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ရပြီ'));
      await tester.pumpAndSettle();

      // Should show completion summary
      expect(find.text('ကျက်မှတ်မှု ပြီးမြောက်ပါပြီ'), findsOneWidget);
      expect(find.text('ပြန်စမည်'), findsOneWidget);
      expect(find.text('ပြီးပါပြီ'), findsOneWidget);
    });
  });

  group('WordShareDialog Widget Tests', () {
    final sampleWord = VocabItem(
      paliMm: 'မေတ္တာ',
      paliRoman: 'mettā',
      translateMm: 'ချစ်ခင်မြတ်နိုးခြင်း',
      translateEn: 'Loving-kindness',
      example: ExampleSentence(
        paliMm: 'သဗ္ဗေ သတ္တာ သုခိတာ ဟောန္တု',
        paliRoman: 'sabbe sattā sukhitā hontu',
        translateMm: 'သတ္တဝါအားလုံး ချမ်းသာကြပါစေ',
        translateEn: 'May all beings be happy',
      ),
    );

    testWidgets('renders word share dialog preview and actions', (tester) async {
      final dialog = WordShareDialog(
        word: sampleWord,
        isMyanmar: true,
        categoryTitle: 'မေတ္တာသုတ်',
      );

      // Verify generated share text contents
      expect(dialog.shareText, contains('မေတ္တာ'));
      expect(dialog.shareText, contains('mettā'));
      expect(dialog.shareText, contains('သဗ္ဗေ သတ္တာ သုခိတာ ဟောန္တု'));
      expect(dialog.shareText, contains('Pali Bank'));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: dialog,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('မေတ္တာ'), findsOneWidget);
      expect(find.text('mettā'), findsOneWidget);
      expect(find.textContaining('သဗ္ဗေ သတ္တာ သုခိတာ ဟောန္တု'), findsOneWidget);
      expect(find.text('Viber'), findsOneWidget);
      expect(find.text('Telegram'), findsOneWidget);
      expect(find.text('ကူးယူရန်'), findsOneWidget);
      expect(find.text('ပိတ်ပါ'), findsOneWidget);
    });
  });
}
