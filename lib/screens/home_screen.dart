import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_data.dart';
import '../main.dart' show AppLanguage, appData;
import '../pali_transliteration.dart';
import '../remote_app_config.dart';
import '../services/learning_stats_service.dart';
import '../services/tts_service.dart';
import '../widgets/language_mode_switcher.dart';
import '../widgets/word_share_dialog.dart';
import 'data_download_sheet.dart';
import 'detail_content_screen.dart';
import 'flashcard_screen.dart';
import 'pali_chat_screen.dart';
import 'sub_category_screen.dart';
import 'vocabulary_quiz_screen.dart';

class _SearchWordResult {
  final VocabItem item;
  final MainCategory category;
  final SubCategory subCategory;

  const _SearchWordResult({
    required this.item,
    required this.category,
    required this.subCategory,
  });
}

// 1. Home Screen (Grid View with Modern Square Cards)
class HomeScreen extends StatefulWidget {
  final AppLanguage currentLang;
  final VoidCallback onLanguageToggle;
  final ValueNotifier<int> selectedTab;
  final Set<String> savedWords;
  final ValueChanged<VocabItem> onSavedWordToggle;
  final double textScale;
  final ValueChanged<double> onTextScaleChanged;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final VoidCallback onCheckCodeUpdate;

  const HomeScreen({
    super.key,
    required this.currentLang,
    required this.onLanguageToggle,
    required this.selectedTab,
    required this.savedWords,
    required this.onSavedWordToggle,
    required this.textScale,
    required this.onTextScaleChanged,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.onCheckCodeUpdate,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  static const _dailyLearningExcludedIds = {
    'dialogues',
    'conversation_patterns',
    'pali_stories',
  };
  Set<String>? _selectedDailyCategoryIds;

  List<MainCategory> get _dailyLearningCategories => appData
      .where((category) => !_dailyLearningExcludedIds.contains(category.id))
      .where(
        (category) => category.subCategories.any(
          (subCategory) => (subCategory.vocabList ?? []).isNotEmpty,
        ),
      )
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    unawaited(_loadDailyLearningCategories());
    unawaited(LearningStatsService.recordDailyActive());
  }

  Future<void> _loadDailyLearningCategories() async {
    final preferences = await SharedPreferences.getInstance();
    final available = _dailyLearningCategories
        .map((category) => category.id)
        .toSet();
    final saved = preferences.getStringList('daily_learning_category_ids');
    if (!mounted) return;
    setState(
      () => _selectedDailyCategoryIds = saved == null
          ? available
          : saved.toSet().intersection(available),
    );
  }

  Future<void> _setDailyLearningCategories(Set<String> ids) async {
    final available = _dailyLearningCategories
        .map((category) => category.id)
        .toSet();
    final selection = ids.intersection(available);
    setState(() => _selectedDailyCategoryIds = selection);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'daily_learning_category_ids',
      selection.toList()..sort(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_SearchWordResult> _findWords(String query) {
    final normalizedQuery = normalizePaliSearch(query);
    if (normalizedQuery.isEmpty) return [];

    return _allSearchableItems()
        .where(
          (result) => [
            result.item.paliMm,
            result.item.paliRoman,
            result.item.translateMm,
            result.item.translateEn,
          ].any(
            (value) => normalizePaliSearch(value).contains(normalizedQuery),
          ),
        )
        .toList();
  }

  List<_SearchWordResult> _allSearchableItems() {
    final results = <_SearchWordResult>[];
    for (final category in RemoteAppConfigRepository.current.apply(
      AppDataRepository.categories,
      includeHidden: true,
    )) {
      for (final subCategory in category.subCategories) {
        for (final item in subCategory.vocabList ?? const <VocabItem>[]) {
          results.add(
            _SearchWordResult(
              item: item,
              category: category,
              subCategory: subCategory,
            ),
          );
        }
        for (final dialogue in subCategory.dialogueList ?? const []) {
          results.add(
            _SearchWordResult(
              item: VocabItem(
                paliMm: dialogue.paliMm,
                paliRoman: dialogue.paliRoman,
                translateMm: dialogue.translateMm,
                translateEn: dialogue.translateEn,
              ),
              category: category,
              subCategory: subCategory,
            ),
          );
        }
        final story = subCategory.story;
        if (story != null) {
          for (final sentence in story.sentences) {
            results.add(
              _SearchWordResult(
                item: VocabItem(
                  paliMm: sentence.paliMm,
                  paliRoman: sentence.paliRoman,
                  translateMm: sentence.translateMm,
                  translateEn: sentence.translateEn,
                ),
                category: category,
                subCategory: subCategory,
              ),
            );
          }
        }
      }
    }
    return results;
  }

  List<_SearchWordResult> _allWords() {
    return [
      for (final category in RemoteAppConfigRepository.current.apply(
        AppDataRepository.categories,
        includeHidden: true,
      ))
        for (final subCategory in category.subCategories)
          for (final item in subCategory.vocabList ?? [])
            _SearchWordResult(
              item: item,
              category: category,
              subCategory: subCategory,
            ),
    ];
  }

  Widget _buildHome(bool isMm) {
    final config = RemoteAppConfigRepository.current;
    final selectedIds =
        _selectedDailyCategoryIds ??
        _dailyLearningCategories.map((category) => category.id).toSet();
    final words = _allWords()
        .where((result) => selectedIds.contains(result.category.id))
        .toList(growable: false);
    if (words.isEmpty) {
      return Center(
        child: Text(
          isMm
              ? 'ရွေးချယ်ထားသော အမျိုးအစားတွင် သင်ခန်းစာ မရှိပါ။'
              : 'No lessons are available in the selected categories.',
        ),
      );
    }
    final today = DateTime.now();
    final dayIndex =
        today.difference(DateTime(today.year)).inDays % words.length;
    final dailyWord = words[dayIndex].item;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (config.home.showDailyWord)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF762319),
                  Color(0xFF9A4329),
                  Color(0xFFB96A36),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wb_sunny_outlined, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      isMm ? 'ယနေ့လေ့လာရန်' : 'WORD OF THE DAY',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: isMm ? 'အသံနားထောင်ရန်' : 'Listen',
                      onPressed: () =>
                          TtsService.speakPali(dailyWord.paliRoman),
                      color: Colors.white,
                      icon: const Icon(Icons.volume_up_rounded),
                    ),
                    IconButton(
                      tooltip: isMm ? 'စကားလုံး မျှဝေရန်' : 'Share card',
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (dialogContext) => WordShareDialog(
                          word: dailyWord,
                          isMyanmar: isMm,
                        ),
                      ),
                      color: Colors.white,
                      icon: const Icon(Icons.share_rounded),
                    ),
                    IconButton(
                      tooltip: widget.savedWords.contains(dailyWord.paliRoman)
                          ? (isMm
                                ? 'သိမ်းထားမှုမှ ဖယ်ရန်'
                                : 'Remove saved word')
                          : (isMm ? 'သိမ်းရန်' : 'Save word'),
                      onPressed: () => widget.onSavedWordToggle(dailyWord),
                      color: Colors.white,
                      icon: Icon(
                        widget.savedWords.contains(dailyWord.paliRoman)
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isMm ? dailyWord.paliMm : dailyWord.paliRoman,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isMm ? dailyWord.translateMm : dailyWord.translateEn,
                  style: const TextStyle(color: Colors.white, fontSize: 17),
                ),
              ],
            ),
          ),
        if (config.home.showStatistics) ...[
          const SizedBox(height: 16),
          _buildStatisticsBanner(isMm),
        ],
        const SizedBox(height: 24),
        if (config.home.showExploreHeading)
          Row(
            children: [
              Expanded(
                child: Text(
                  isMm ? 'အကြောင်းအရာများ' : 'Explore topics',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = config.home.columns;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: appData.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.25,
              ),
              itemBuilder: (context, index) {
                final category = appData[index];
                return Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => SubCategoryScreen(
                          category: category,
                          currentLang: widget.currentLang,
                          onLanguageToggle: widget.onLanguageToggle,
                          savedWords: widget.savedWords,
                          onSavedWordToggle: widget.onSavedWordToggle,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            category.icon,
                            size: 24,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: Text(
                                  isMm ? category.titleMm : category.titleEn,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatisticsBanner(bool isMm) {
    return ValueListenableBuilder<int>(
      valueListenable: LearningStatsService.statsRevision,
      builder: (context, _, child) {
        return FutureBuilder<LearningStats>(
          future: LearningStatsService.getStats(),
          builder: (context, snapshot) {
            final stats = snapshot.data ??
                const LearningStats(
                  streakDays: 0,
                  masteredWordsCount: 0,
                  quizTotalAnswered: 0,
                  quizTotalCorrect: 0,
                );
            final totalWords = _allWords().length;
            final unlockedBadges =
                stats.badges.where((b) => b.unlocked).length;

            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: Colors.deepOrange,
                          value: '${stats.streakDays} ${isMm ? 'ရက်' : 'd'}',
                          label: isMm ? 'ရက်ဆက်' : 'Streak',
                        ),
                        Container(
                          height: 36,
                          width: 1,
                          color: Theme.of(context).dividerColor.withValues(
                                alpha: 0.5,
                              ),
                        ),
                        _buildStatItem(
                          icon: Icons.menu_book_rounded,
                          iconColor: Theme.of(context).colorScheme.primary,
                          value: '${stats.masteredWordsCount}/$totalWords',
                          label: isMm ? 'လေ့လာပြီး' : 'Learned',
                        ),
                        Container(
                          height: 36,
                          width: 1,
                          color: Theme.of(context).dividerColor.withValues(
                                alpha: 0.5,
                              ),
                        ),
                        _buildStatItem(
                          icon: Icons.track_changes_rounded,
                          iconColor: Colors.green.shade700,
                          value: stats.quizTotalAnswered == 0
                              ? '—'
                              : '${stats.quizAccuracyPercent}%',
                          label: isMm ? 'တိကျမှု' : 'Accuracy',
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () =>
                          _showBadgesAndGoalDialog(context, stats, isMm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isMm
                                      ? 'နေ့စဉ်ပန်းတိုင်: ${stats.todayWordsCount} / ${stats.dailyGoal}'
                                      : 'Daily Goal: ${stats.todayWordsCount} / ${stats.dailyGoal}',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '🏆 $unlockedBadges/${stats.badges.length}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: stats.dailyGoalProgress,
                                minHeight: 7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (stats.dueWordsCount > 0) ...[
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () => _openDueReviewFlashcards(isMm),
                        icon: const Icon(Icons.history_edu_rounded, size: 18),
                        label: Text(
                          isMm
                              ? 'ယနေ့ ပြန်နွှေးရန် (${stats.dueWordsCount} ခု)'
                              : 'Due Today (${stats.dueWordsCount} words)',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openDueReviewFlashcards(bool isMm) async {
    final dueKeys = await LearningStatsService.getDueWordKeys();
    final dueItems = _allWords()
        .where((result) => dueKeys.contains(result.item.paliRoman))
        .map((result) => result.item)
        .toList();
    if (!mounted) return;
    if (dueItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? 'ယနေ့ ပြန်နွှေးရန် စကားလုံး မရှိတော့ပါ'
                : 'No words due for review today',
          ),
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) =>
            FlashcardScreen(words: dueItems, isMyanmar: isMm),
      ),
    );
  }

  Future<void> _showBadgesAndGoalDialog(
    BuildContext context,
    LearningStats stats,
    bool isMm,
  ) async {
    var selectedGoal = stats.dailyGoal;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isMm
                    ? 'နေ့စဉ်ပန်းတိုင်နှင့် ဂုဏ်ပြုတံဆိပ်များ'
                    : 'Daily Goal & Badges',
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMm ? 'နေ့စဉ် စကားလုံးပန်းတိုင်' : 'Daily Word Goal',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final goal in [5, 10, 15, 20])
                            ChoiceChip(
                              label: Text(
                                isMm ? '$goal လုံး' : '$goal words',
                              ),
                              selected: selectedGoal == goal,
                              onSelected: (selected) async {
                                if (!selected) return;
                                setDialogState(() => selectedGoal = goal);
                                await LearningStatsService.setDailyGoal(goal);
                              },
                            ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        isMm ? 'ဂုဏ်ပြုတံဆိပ်များ' : 'Achievement Badges',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final badge in stats.badges)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Opacity(
                            opacity: badge.unlocked ? 1.0 : 0.35,
                            child: Text(
                              badge.iconEmoji,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                          title: Text(
                            isMm ? badge.titleMm : badge.titleEn,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: badge.unlocked
                                  ? null
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          subtitle: Text(
                            isMm ? badge.descriptionMm : badge.descriptionEn,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: Icon(
                            badge.unlocked
                                ? Icons.verified_rounded
                                : Icons.lock_outline_rounded,
                            color: badge.unlocked
                                ? Colors.green.shade700
                                : Theme.of(context).disabledColor,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(isMm ? 'ပိတ်ပါ' : 'Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSavedWords(bool isMm) {
    final savedWords = _allWords()
        .where((result) => widget.savedWords.contains(result.item.paliRoman))
        .toList();
    if (savedWords.isEmpty) {
      return Center(
        child: Text(
          isMm ? 'မှတ်ထားသော စကားလုံး မရှိသေးပါ' : 'No saved words yet',
        ),
      );
    }

    final practiceWords = savedWords.map((r) => r.item).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => FlashcardScreen(
                        words: practiceWords,
                        isMyanmar: isMm,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.flip_to_back_rounded, size: 18),
                  label: Text(
                    isMm ? 'Flashcard ကျက်မည်' : 'Study Flashcards',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => VocabularyQuizScreen(
                        words: practiceWords,
                        isMyanmar: isMm,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.quiz_rounded, size: 18),
                  label: Text(isMm ? 'Quiz ဖြေမည်' : 'Practice Quiz'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            itemCount: savedWords.length,
            itemBuilder: (context, index) {
              final result = savedWords[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.bookmark_rounded),
                  title: Text(
                    isMm ? result.item.paliMm : result.item.paliRoman,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    '${isMm ? result.item.translateMm : result.item.translateEn}\n'
                    '${isMm ? result.subCategory.titleMm : result.subCategory.titleEn}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: isMm ? 'မှတ်ထားမှုမှ ဖယ်ရန်' : 'Remove saved word',
                    icon: const Icon(Icons.bookmark_remove_outlined),
                    onPressed: () => widget.onSavedWordToggle(result.item),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailContentScreen(
                        subCategory: result.subCategory,
                        currentLang: widget.currentLang,
                        onLanguageToggle: widget.onLanguageToggle,
                        savedWords: widget.savedWords,
                        onSavedWordToggle: widget.onSavedWordToggle,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearch(bool isMm) {
    final results = _findWords(_searchQuery);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: isMm ? 'ပါဠိစကားလုံး ရှာရန်' : 'Search Pāḷi words',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: isMm ? 'ဖျက်ရန်' : 'Clear',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: _searchQuery.trim().isEmpty
              ? Center(
                  child: Text(
                    isMm
                        ? 'ပါဠိစာလုံး သို့မဟုတ် အဓိပ္ပာယ်ကို ရိုက်ရှာပါ'
                        : 'Type a Pāḷi word or meaning to search',
                    textAlign: TextAlign.center,
                  ),
                )
              : results.isEmpty
              ? Center(child: Text(isMm ? 'မတွေ့ပါ' : 'No words found'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return Card(
                      child: ListTile(
                        title: Text(
                          isMm ? result.item.paliMm : result.item.paliRoman,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${isMm ? result.item.translateMm : result.item.translateEn}\n'
                          '${isMm ? result.subCategory.titleMm : result.subCategory.titleEn}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.arrow_forward_ios_rounded),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailContentScreen(
                              subCategory: result.subCategory,
                              currentLang: widget.currentLang,
                              onLanguageToggle: widget.onLanguageToggle,
                              savedWords: widget.savedWords,
                              onSavedWordToggle: widget.onSavedWordToggle,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSettings(bool isMm) {
    final categories = _dailyLearningCategories;
    final selected =
        _selectedDailyCategoryIds ?? categories.map((item) => item.id).toSet();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.text_fields_rounded),
          title: Text(isMm ? 'စာလုံးအရွယ်အစား' : 'Text size'),
          subtitle: Slider(
            value: widget.textScale,
            min: 0.8,
            max: 1.4,
            divisions: 6,
            label: '${(widget.textScale * 100).round()}%',
            onChanged: widget.onTextScaleChanged,
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.dark_mode_outlined),
          title: Text(isMm ? 'အရောင်မုဒ်' : 'Dark mode'),
          subtitle: Text(
            widget.isDarkMode
                ? (isMm ? 'အမှောင်' : 'Dark')
                : (isMm ? 'အလင်း' : 'Light'),
          ),
          value: widget.isDarkMode,
          onChanged: widget.onThemeChanged,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.system_update_alt),
          title: Text(isMm ? 'အက်ပ်အပ်ဒိတ် စစ်ဆေးရန်' : 'Check app updates'),
          subtitle: Text(
            isMm
                ? 'Shorebird code update များကို စစ်ဆေးပါ'
                : 'Check for Shorebird code updates',
          ),
          onTap: widget.onCheckCodeUpdate,
        ),
        const Divider(height: 32),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            isMm
                ? 'ယနေ့လေ့လာရန် အမျိုးအစားများ'
                : 'Today’s learning categories',
          ),
          subtitle: Text(
            '${selected.intersection(categories.map((c) => c.id).toSet()).length}/${categories.length} ${isMm ? 'ရွေးထားသည်' : 'selected'}',
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isMm
                    ? 'ရွေးချယ်ထားသော အမျိုးအစားများမှ စကားလုံးကို ပြသပါမည်။'
                    : 'The daily word comes from your selected categories.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => _setDailyLearningCategories(
                    categories.map((c) => c.id).toSet(),
                  ),
                  child: Text(isMm ? 'အားလုံးရွေးရန်' : 'Select all'),
                ),
                TextButton(
                  onPressed: () => _setDailyLearningCategories({}),
                  child: Text(isMm ? 'အားလုံးဖြုတ်ရန်' : 'Deselect all'),
                ),
              ],
            ),
            for (final category in categories)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(isMm ? category.titleMm : category.titleEn),
                value: selected.contains(category.id),
                onChanged: (value) {
                  final updated = Set<String>.from(selected);
                  if (value ?? false) {
                    updated.add(category.id);
                  } else {
                    updated.remove(category.id);
                  }
                  _setDailyLearningCategories(updated);
                },
              ),
          ],
        ),
        const Divider(height: 32),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cloud_download_outlined),
          title: Text(isMm ? 'ဒေတာ ဒေါင်းလုဒ်' : 'Data downloads'),
          subtitle: Text(_dataStatusLabel(isMm)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (context) => DataDownloadSheet(isMyanmar: isMm),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.cloud_sync_outlined),
          title: Text(isMm ? 'အလိုအလျောက် မွမ်းမံရန်' : 'Auto update'),
          subtitle: Text(
            isMm
                ? 'အက်ပ်ဖွင့်ချိန်တွင် ဒေတာအသစ်များကို အလိုအလျောက် ရယူပါမည်'
                : 'Download newer data automatically when the app opens',
          ),
          value: AppDataRepository.autoUpdateEnabled,
          onChanged: (value) async {
            await AppDataRepository.setAutoUpdate(value);
            if (!mounted) return;
            setState(() {});
          },
        ),
        const Divider(height: 32),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.speed_rounded),
          title: Text(isMm ? 'အသံထွက်နှုန်း' : 'Speech rate'),
          subtitle: Wrap(
            spacing: 8,
            children: [
              for (final rate in [0.3, 0.45, 0.6])
                ChoiceChip(
                  label: Text('${rate}x'),
                  selected: (TtsService.speechRate - rate).abs() < 0.05,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        TtsService.setSpeechRate(rate);
                      });
                    }
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _dataStatusLabel(bool isMm) {
    if (!AppDataRepository.initialized || AppDataRepository.datasets.isEmpty) {
      return isMm ? 'ဒေတာ အခြေအနေ မရနိုင်သေးပါ' : 'Data status unavailable';
    }
    final updates = AppDataRepository.updatesAvailable;
    if (updates == 0) {
      return isMm ? 'ဒေတာအားလုံး နောက်ဆုံးဖြစ်သည်' : 'All data is up to date';
    }
    return isMm
        ? 'မွမ်းမံရန် $updates ခု ရှိသည်'
        : '$updates update(s) available';
  }

  Widget _aboutSection(String heading, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(description),
        ],
      ),
    );
  }

  Future<void> _openContactLink(
    BuildContext context,
    Uri uri,
    bool isMm,
  ) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uri.scheme == 'viber'
                  ? (isMm
                        ? 'Viber ကို ဖွင့်၍မရပါ။ Viber အက်ပ်ကို ထည့်သွင်းထားကြောင်း စစ်ဆေးပြီး ထပ်မံကြိုးစားပါ။'
                        : 'Could not open Viber. Make sure it is installed, then try again.')
                  : (isMm
                        ? 'Email အက်ပ်ကို ဖွင့်၍မရပါ။ Email အက်ပ်တစ်ခု ထည့်သွင်းထားကြောင်း စစ်ဆေးပါ။'
                        : 'Could not open an email app. Make sure one is installed, then try again.'),
            ),
          ),
        );
      }
    } on Exception catch (error) {
      debugPrint('Could not open contact link: $error');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uri.scheme == 'viber'
                ? (isMm
                      ? 'Viber လင့်ခ်ကို ဖွင့်၍မရပါ။ Viber အက်ပ်ကို ထည့်သွင်းထားကြောင်း စစ်ဆေးပြီး ထပ်မံကြိုးစားပါ။'
                      : 'Could not open the Viber link. Make sure Viber is installed, then try again.')
                : (isMm
                      ? 'Email လင့်ခ်ကို ဖွင့်၍မရပါ။ Email အက်ပ်တစ်ခု ထည့်သွင်းထားကြောင်း စစ်ဆေးပါ။'
                      : 'Could not open the email link. Make sure an email app is installed, then try again.'),
          ),
        ),
      );
    }
  }

  Widget _buildDrawer(BuildContext context, bool isMm) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Image.asset(
                    'assets/pali_bank_logo.png',
                    width: 46,
                    height: 46,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Text(
                      isMm ? 'ပါဠိဝေါဟာရများ' : 'Pāḷi Vocabularies',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.forum_outlined),
            title: Text(isMm ? 'ပါဠိစကားပြောခန်း' : 'Pāḷi Community Chat'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => PaliChatScreen(isMyanmar: isMm),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(isMm ? 'အက်ပ်အကြောင်း' : 'About app'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(isMm ? 'အက်ပ်အကြောင်း' : 'About this app'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _aboutSection(
                          isMm ? 'မိတ်ဆက်' : 'Overview',
                          isMm
                              ? 'Pali Bank သည် ပါဠိဘာသာကို အခြေခံမှစ၍ အဆင့်လိုက် လေ့လာနိုင်ရန် ရည်ရွယ်ထားသော ပညာရေးအက်ပ်ဖြစ်ပါသည်။ သင်ခန်းစာများနှင့် လက်တွေ့အသုံးချစကားလုံးများကို မြန်မာနှင့် အင်္ဂလိပ်ဘာသာဖြင့် လေ့လာနိုင်ပါသည်။'
                              : 'Pali Bank is an educational app for learning Pāḷi step by step, with lessons and practical vocabulary available in Myanmar and English.',
                        ),
                        _aboutSection(
                          isMm
                              ? 'သင်ခန်းစာနှင့် လေ့လာစရာများ'
                              : 'Learning resources',
                          isMm
                              ? 'နာမ်၊ ကြိယာ၊ နာမဝိသေသန၊ ကြိယာဝိသေသန၊ နိပါတ်နှင့် အချိန်ပြနိပါတ်များ၊ ပညာရေးဆိုင်ရာ ကြိယာများ၊ နေ့စဉ်သုံး စကားပြောခန်းများနှင့် ပါဠိပုံပြင်များ ပါဝင်ပါသည်။'
                              : 'Explore nouns, verbs, adjectives, adverbs, particles including time particles, academic learning verbs, everyday dialogues, and Pāḷi stories.',
                        ),
                        _aboutSection(
                          isMm
                              ? 'အသုံးဝင်သော လုပ်ဆောင်ချက်များ'
                              : 'Learning tools',
                          isMm
                              ? 'စကားလုံးများကို ရှာဖွေခြင်း၊ နေ့စဉ်စကားလုံးနှင့် အသံထွက်ကို လေ့လာခြင်း၊ စိတ်ဝင်စားသော စကားလုံးများကို သိမ်းဆည်းခြင်းနှင့် သင်ခန်းစာအလိုက် လေ့ကျင့်ခန်းများ ဖြေဆိုခြင်းတို့ ပြုလုပ်နိုင်ပါသည်။'
                              : 'Search vocabulary, study the word of the day and its pronunciation, save useful words, and practice with lesson quizzes.',
                        ),
                        _aboutSection(
                          isMm ? 'ဒေတာနှင့် အသုံးပြုမှု' : 'Data and updates',
                          isMm
                              ? 'ဒေါင်းလုဒ်လုပ်ထားသော သင်ခန်းစာများကို အင်တာနက်မရှိချိန်တွင်လည်း အသုံးပြုနိုင်ပါသည်။ ဆက်တင်မှ ဒေတာအသစ်များကို စစ်ဆေးပြီး ကိုယ်တိုင် သို့မဟုတ် အလိုအလျောက် ရယူနိုင်ပါသည်။'
                              : 'Downloaded lessons remain available offline. Check Settings for new data and download updates manually or automatically.',
                        ),
                        _aboutSection(
                          isMm ? 'အက်ပ်ဖန်တီးသူ' : 'Created by',
                          'အရှင်ဣန္ဒကာလင်္ကာရ (Ven. Indakālaṅkāra)',
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(isMm ? 'ပိတ်ပါ' : 'Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.contact_mail_outlined),
            title: Text(isMm ? 'ဆက်သွယ်ရန်' : 'Contact'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(isMm ? 'ဆက်သွယ်ရန်' : 'Contact'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isMm
                            ? 'မေးမြန်းရန် သို့မဟုတ် အကြံပြုရန် အောက်ပါနည်းလမ်းကို နှိပ်ပါ။'
                            : 'Tap an option below to get in touch or share feedback.',
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Email'),
                        subtitle: const Text('palimalafamily@gmail.com'),
                        onTap: () => _openContactLink(
                          dialogContext,
                          Uri(
                            scheme: 'mailto',
                            path: 'palimalafamily@gmail.com',
                          ),
                          isMm,
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.phone_in_talk_outlined),
                        title: const Text('Viber'),
                        subtitle: const Text(
                          '+959426882932',
                          locale: Locale('en', 'US'),
                          style: TextStyle(fontFamily: 'SourceSans3'),
                        ),
                        onTap: () => _openContactLink(
                          dialogContext,
                          Uri(
                            scheme: 'viber',
                            host: 'chat',
                            queryParameters: const {'number': '+959426882932'},
                          ),
                          isMm,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(isMm ? 'ပိတ်ပါ' : 'Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.selectedTab,
      builder: (context, selectedIndex, _) {
        final isMm = widget.currentLang == AppLanguage.myanmar;
        final titles = [
          isMm ? 'ပါဠိဝေါဟာရများ' : 'Pāḷi Vocabularies',
          isMm ? 'စကားလုံးရှာရန်' : 'Search Word',
          isMm ? 'ပါဠိစကားပြောခန်း' : 'Pāḷi Chat',
          isMm ? 'မှတ်ထားသည်များ' : 'Saved Words',
          isMm ? 'ဆက်တင်များ' : 'Settings',
        ];

        return Scaffold(
          drawer: _buildDrawer(context, isMm),
          appBar: AppBar(
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                tooltip: isMm ? 'မီနူး' : 'Menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/pali_bank_logo.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    titles[selectedIndex],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              LanguageModeSwitcher(
                currentLang: widget.currentLang,
                onLanguageToggle: widget.onLanguageToggle,
              ),
            ],
          ),
          body: selectedIndex == 0
              ? _buildHome(isMm)
              : selectedIndex == 1
              ? _buildSearch(isMm)
              : selectedIndex == 2
              ? PaliChatScreen(isMyanmar: isMm, embedded: true)
              : selectedIndex == 3
              ? _buildSavedWords(isMm)
              : _buildSettings(isMm),
        );
      },
    );
  }
}
