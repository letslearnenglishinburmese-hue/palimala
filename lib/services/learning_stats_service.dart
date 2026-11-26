import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SrsWordState {
  final int intervalDays;
  final int repetitions;
  final String nextReviewDate; // YYYY-MM-DD

  const SrsWordState({
    required this.intervalDays,
    required this.repetitions,
    required this.nextReviewDate,
  });

  factory SrsWordState.fromJson(Map<String, dynamic> json) {
    return SrsWordState(
      intervalDays: (json['intervalDays'] as num?)?.toInt() ?? 0,
      repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
      nextReviewDate: (json['nextReviewDate'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'intervalDays': intervalDays,
        'repetitions': repetitions,
        'nextReviewDate': nextReviewDate,
      };
}

class AchievementBadge {
  final String id;
  final String titleMm;
  final String titleEn;
  final String descriptionMm;
  final String descriptionEn;
  final String iconEmoji;
  final bool unlocked;

  const AchievementBadge({
    required this.id,
    required this.titleMm,
    required this.titleEn,
    required this.descriptionMm,
    required this.descriptionEn,
    required this.iconEmoji,
    required this.unlocked,
  });
}

class LearningStats {
  final int streakDays;
  final int masteredWordsCount;
  final int quizTotalAnswered;
  final int quizTotalCorrect;
  final int dailyGoal;
  final int todayWordsCount;
  final int dueWordsCount;

  const LearningStats({
    required this.streakDays,
    required this.masteredWordsCount,
    required this.quizTotalAnswered,
    required this.quizTotalCorrect,
    this.dailyGoal = 10,
    this.todayWordsCount = 0,
    this.dueWordsCount = 0,
  });

  int get quizAccuracyPercent {
    if (quizTotalAnswered == 0) return 0;
    return ((quizTotalCorrect / quizTotalAnswered) * 100).round();
  }

  double get dailyGoalProgress {
    if (dailyGoal <= 0) return 0;
    return (todayWordsCount / dailyGoal).clamp(0.0, 1.0);
  }

  List<AchievementBadge> get badges => [
        AchievementBadge(
          id: 'first_step',
          titleMm: 'စတင်လေ့လာသူ',
          titleEn: 'First Step',
          descriptionMm: 'ပထမဆုံး ပါဠိစကားလုံး သို့မဟုတ် လေ့ကျင့်ခန်း စတင်ပြီးမြောက်ခြင်း',
          descriptionEn: 'Complete your first word or practice session',
          iconEmoji: '🌱',
          unlocked:
              streakDays >= 1 || masteredWordsCount >= 1 || quizTotalAnswered >= 1,
        ),
        AchievementBadge(
          id: 'streak_3',
          titleMm: 'ဝီရိယ',
          titleEn: 'Diligent (3-Day Streak)',
          descriptionMm: '၃ ရက်ဆက်တိုက် ပါဠိစာပေ လေ့လာခြင်း',
          descriptionEn: 'Study Pāḷi for 3 consecutive days',
          iconEmoji: '🔥',
          unlocked: streakDays >= 3,
        ),
        AchievementBadge(
          id: 'streak_7',
          titleMm: 'သဒ္ဓါဝီရိယ',
          titleEn: 'Steadfast (7-Day Streak)',
          descriptionMm: '၇ ရက်ဆက်တိုက် မပျက်မကွက် လေ့လာခြင်း',
          descriptionEn: 'Study Pāḷi for 7 consecutive days',
          iconEmoji: '🏆',
          unlocked: streakDays >= 7,
        ),
        AchievementBadge(
          id: 'words_25',
          titleMm: 'ဝေါဟာရစုဆောင်းသူ',
          titleEn: 'Word Collector (25+)',
          descriptionMm: 'စကားလုံး ၂၅ လုံးနှင့်အထက် ကျက်မှတ်နိုင်ခြင်း',
          descriptionEn: 'Master 25 or more Pāḷi words',
          iconEmoji: '📚',
          unlocked: masteredWordsCount >= 25,
        ),
        AchievementBadge(
          id: 'words_100',
          titleMm: 'ပါဠိပညာရှင်',
          titleEn: 'Pāḷi Scholar (100+)',
          descriptionMm: 'စကားလုံး ၁၀၀ နှင့်အထက် ကျက်မှတ်နိုင်ခြင်း',
          descriptionEn: 'Master 100 or more Pāḷi words',
          iconEmoji: '👑',
          unlocked: masteredWordsCount >= 100,
        ),
        AchievementBadge(
          id: 'quiz_ace',
          titleMm: 'ဉာဏ်ပညာရှင်',
          titleEn: 'Quiz Ace (90%+)',
          descriptionMm: 'မေးခွန်း ၁၀ ခုနှင့်အထက် ဖြေဆိုပြီး တိကျမှု ၉၀% အထက်ရရှိခြင်း',
          descriptionEn: 'Achieve 90%+ accuracy across at least 10 quiz questions',
          iconEmoji: '🎯',
          unlocked: quizTotalAnswered >= 10 && quizAccuracyPercent >= 90,
        ),
      ];
}

class LearningStatsService {
  static const _streakKey = 'pali_streak_count';
  static const _lastActiveDateKey = 'pali_last_active_date';
  static const _quizAnsweredKey = 'pali_quiz_total_answered';
  static const _quizCorrectKey = 'pali_quiz_total_correct';
  static const _masteredWordsKey = 'pali_mastered_words';
  static const _srsRecordsKey = 'pali_srs_records';
  static const _dailyGoalKey = 'pali_daily_goal';
  static const _todayDateKey = 'pali_today_date';
  static const _todayWordsCountKey = 'pali_today_words_count';

  static final ValueNotifier<int> statsRevision = ValueNotifier<int>(0);

  /// Formats date to 'YYYY-MM-DD'
  static String formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Records learning activity today and calculates streak
  static Future<void> recordDailyActive({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = now ?? DateTime.now();
    final todayStr = formatDate(today);
    final lastActiveStr = prefs.getString(_lastActiveDateKey);

    if (lastActiveStr == todayStr) {
      return;
    }

    int currentStreak = prefs.getInt(_streakKey) ?? 0;

    if (lastActiveStr != null) {
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayStr = formatDate(yesterday);
      if (lastActiveStr == yesterdayStr) {
        currentStreak += 1;
      } else {
        currentStreak = 1;
      }
    } else {
      currentStreak = 1;
    }

    await prefs.setInt(_streakKey, currentStreak);
    await prefs.setString(_lastActiveDateKey, todayStr);
    statsRevision.value++;
  }

  static Future<void> _incrementTodayWords(
    SharedPreferences prefs,
    int count, {
    DateTime? now,
  }) async {
    final todayStr = formatDate(now ?? DateTime.now());
    final savedDate = prefs.getString(_todayDateKey);
    final currentCount =
        savedDate == todayStr ? (prefs.getInt(_todayWordsCountKey) ?? 0) : 0;
    await prefs.setString(_todayDateKey, todayStr);
    await prefs.setInt(_todayWordsCountKey, currentCount + count);
  }

  static Future<void> setDailyGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyGoalKey, goal.clamp(1, 200));
    statsRevision.value++;
  }

  /// Records a completed quiz session
  static Future<void> recordQuizResult({
    required int total,
    required int correct,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final currentAnswered = prefs.getInt(_quizAnsweredKey) ?? 0;
    final currentCorrect = prefs.getInt(_quizCorrectKey) ?? 0;

    await prefs.setInt(_quizAnsweredKey, currentAnswered + total);
    await prefs.setInt(_quizCorrectKey, currentCorrect + correct);
    await _incrementTodayWords(prefs, total);
    await recordDailyActive();
    statsRevision.value++;
  }

  /// Marks a word as mastered (e.g. from Flashcard SRS or Quiz)
  static Future<void> markWordLearned(
    String paliRoman, {
    required bool mastered,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final masteredList = prefs.getStringList(_masteredWordsKey) ?? [];
    final masteredSet = masteredList.toSet();

    if (mastered) {
      masteredSet.add(paliRoman);
    } else {
      masteredSet.remove(paliRoman);
    }

    await prefs.setStringList(_masteredWordsKey, masteredSet.toList());
    await recordDailyActive();
    statsRevision.value++;
  }

  static Map<String, SrsWordState> _decodeSrsRecords(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key: SrsWordState.fromJson(
              entry.value as Map<String, dynamic>,
            ),
      };
    } catch (_) {
      return {};
    }
  }

  /// Schedules the next spaced-repetition review date for [paliRoman]
  /// based on [level] ('again', 'hard', 'easy').
  static Future<SrsWordState> recordSrsReview(
    String paliRoman,
    String level, {
    DateTime? now,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = now ?? DateTime.now();
    final todayStr = formatDate(today);
    final records = _decodeSrsRecords(prefs.getString(_srsRecordsKey));
    final prev = records[paliRoman];

    late final int nextInterval;
    late final int nextReps;
    if (level == 'again') {
      nextInterval = 0;
      nextReps = 0;
    } else if (level == 'hard') {
      nextInterval = (prev?.intervalDays ?? 0) == 0 ? 1 : prev!.intervalDays;
      nextReps = prev?.repetitions ?? 0;
    } else {
      // 'easy': 1 -> 3 -> 7 -> 14 -> ...
      final reps = prev?.repetitions ?? 0;
      if (reps == 0) {
        nextInterval = 1;
      } else if (reps == 1) {
        nextInterval = 3;
      } else if (reps == 2) {
        nextInterval = 7;
      } else {
        nextInterval = ((prev?.intervalDays ?? 7) * 2).clamp(7, 180);
      }
      nextReps = reps + 1;
    }

    final nextDateStr =
        formatDate(today.add(Duration(days: nextInterval)));
    final updated = SrsWordState(
      intervalDays: nextInterval,
      repetitions: nextReps,
      nextReviewDate: nextDateStr,
    );
    records[paliRoman] = updated;

    await prefs.setString(
      _srsRecordsKey,
      jsonEncode({
        for (final e in records.entries) e.key: e.value.toJson(),
      }),
    );

    final masteredList = prefs.getStringList(_masteredWordsKey) ?? [];
    final masteredSet = masteredList.toSet();
    if (level == 'easy') {
      masteredSet.add(paliRoman);
    } else if (level == 'again') {
      masteredSet.remove(paliRoman);
    }
    await prefs.setStringList(_masteredWordsKey, masteredSet.toList());
    await _incrementTodayWords(prefs, 1, now: today);
    if (lastActiveNeedsUpdate(prefs, todayStr)) {
      await recordDailyActive(now: today);
    }
    statsRevision.value++;
    return updated;
  }

  static bool lastActiveNeedsUpdate(SharedPreferences prefs, String todayStr) {
    return prefs.getString(_lastActiveDateKey) != todayStr;
  }

  /// Returns all word keys (`paliRoman`) whose scheduled review date is today or earlier.
  static Future<Set<String>> getDueWordKeys({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = formatDate(now ?? DateTime.now());
    final records = _decodeSrsRecords(prefs.getString(_srsRecordsKey));
    return {
      for (final entry in records.entries)
        if (entry.value.nextReviewDate.compareTo(todayStr) <= 0) entry.key,
    };
  }

  /// Returns current learning statistics snapshot
  static Future<LearningStats> getStats({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = now ?? DateTime.now();
    final todayStr = formatDate(today);
    final lastActiveStr = prefs.getString(_lastActiveDateKey);
    var streak = prefs.getInt(_streakKey) ?? 0;

    if (lastActiveStr != null && lastActiveStr != todayStr) {
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayStr = formatDate(yesterday);
      if (lastActiveStr != yesterdayStr) {
        streak = 0;
      }
    }

    final masteredList = prefs.getStringList(_masteredWordsKey) ?? [];
    final answered = prefs.getInt(_quizAnsweredKey) ?? 0;
    final correct = prefs.getInt(_quizCorrectKey) ?? 0;
    final dailyGoal = prefs.getInt(_dailyGoalKey) ?? 10;
    final savedTodayDate = prefs.getString(_todayDateKey);
    final todayWords = savedTodayDate == todayStr
        ? (prefs.getInt(_todayWordsCountKey) ?? 0)
        : 0;
    final records = _decodeSrsRecords(prefs.getString(_srsRecordsKey));
    final dueCount = records.values
        .where((r) => r.nextReviewDate.compareTo(todayStr) <= 0)
        .length;

    return LearningStats(
      streakDays: streak,
      masteredWordsCount: masteredList.length,
      quizTotalAnswered: answered,
      quizTotalCorrect: correct,
      dailyGoal: dailyGoal,
      todayWordsCount: todayWords,
      dueWordsCount: dueCount,
    );
  }
}
