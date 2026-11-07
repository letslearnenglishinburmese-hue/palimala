import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_data.dart';
import 'firebase_options.dart';
import 'pali_transliteration.dart';
import 'remote_app_config.dart';

late List<MainCategory> appData;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    appData = await AppDataRepository.load();
  } on Object catch (error) {
    // Keep the shell usable even if local preferences or bundled lessons fail.
    appData = const [];
    debugPrint(
      'Local lesson bootstrap failed; opening the offline app shell: $error',
    );
  }
  try {
    await RemoteAppConfigRepository.load();
    appData = RemoteAppConfigRepository.current.apply(appData);
  } on Object catch (error) {
    debugPrint('Using built-in app defaults: $error');
  }
  runApp(const PaliLearningApp());
  unawaited(
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).then<void>((_) {}).catchError((Object error) {
      debugPrint(
        'Firebase initialization failed; offline features remain available: $error',
      );
    }),
  );
}

// Language Enum
enum AppLanguage { myanmar, english }

class PaliLearningApp extends StatefulWidget {
  const PaliLearningApp({super.key});

  @override
  State<PaliLearningApp> createState() => _PaliLearningAppState();
}

class _PaliLearningAppState extends State<PaliLearningApp> {
  AppLanguage currentLang = AppLanguage.myanmar;
  double _textScale = 1;
  bool _isDarkMode = false;
  final Set<String> _savedWords = {};
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final ValueNotifier<int> _selectedTab = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    appData = RemoteAppConfigRepository.current.apply(
      AppDataRepository.categories,
    );
    appDataRevision.addListener(_handleDataChanged);
    _loadSavedWords();
  }

  @override
  void reassemble() {
    super.reassemble();
    unawaited(AppDataRepository.reloadBundled());
  }

  /// Keeps the shared [appData] in sync when a data set is downloaded or
  /// updated from the settings screen.
  void _handleDataChanged() {
    if (!mounted) return;
    setState(
      () => appData = RemoteAppConfigRepository.current.apply(
        AppDataRepository.categories,
      ),
    );
  }

  Future<void> _loadSavedWords() async {
    final preferences = await SharedPreferences.getInstance();
    final savedWords = preferences.getStringList('saved_pali_words') ?? [];
    if (!mounted) return;
    setState(() {
      _savedWords
        ..clear()
        ..addAll(savedWords);
    });
  }

  Future<void> _toggleSavedWord(VocabItem item) async {
    setState(() {
      if (!_savedWords.add(item.paliRoman)) {
        _savedWords.remove(item.paliRoman);
      }
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('saved_pali_words', _savedWords.toList());
  }

  void toggleLanguage() {
    setState(() {
      currentLang = currentLang == AppLanguage.myanmar
          ? AppLanguage.english
          : AppLanguage.myanmar;
    });
  }

  void _updateTextScale(double value) {
    setState(() => _textScale = value);
  }

  void _toggleTheme(bool value) {
    setState(() => _isDarkMode = value);
  }

  @override
  void dispose() {
    appDataRevision.removeListener(_handleDataChanged);
    _selectedTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = RemoteAppConfigRepository.current;
    final light = config.lightColors;
    final dark = config.darkColors;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pāḷi Learning App',
      theme: buildRemoteTheme(config, dark: false),
      darkTheme: buildRemoteTheme(config, dark: true),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(_textScale)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        body: Navigator(
          key: _navigatorKey,
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            builder: (context) => HomeScreen(
              currentLang: currentLang,
              onLanguageToggle: toggleLanguage,
              selectedTab: _selectedTab,
              savedWords: _savedWords,
              onSavedWordToggle: _toggleSavedWord,
              textScale: _textScale,
              onTextScaleChanged: _updateTextScale,
              isDarkMode: _isDarkMode,
              onThemeChanged: _toggleTheme,
            ),
          ),
        ),
        bottomNavigationBar: ValueListenableBuilder<int>(
          valueListenable: _selectedTab,
          builder: (context, selectedIndex, _) => NavigationBar(
            selectedIndex: selectedIndex,
            height: 60,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            backgroundColor: _isDarkMode ? dark['surface'] : light['surface'],
            indicatorColor: (_isDarkMode ? dark['primary'] : light['primary'])!
                .withValues(alpha: 0.14),
            onDestinationSelected: (index) {
              _navigatorKey.currentState?.popUntil((route) => route.isFirst);
              _selectedTab.value = index;
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: currentLang == AppLanguage.myanmar ? 'ပင်မ' : 'Home',
              ),
              NavigationDestination(
                icon: const Icon(Icons.search_rounded),
                label: currentLang == AppLanguage.myanmar
                    ? 'ရှာရန်'
                    : 'Search Word',
              ),
              NavigationDestination(
                icon: const Icon(Icons.bookmark_border_rounded),
                selectedIcon: const Icon(Icons.bookmark_rounded),
                label: currentLang == AppLanguage.myanmar
                    ? 'မှတ်ထားသည်များ'
                    : 'Saved',
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings_rounded),
                label: currentLang == AppLanguage.myanmar
                    ? 'ဆက်တင်'
                    : 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Global Text To Speech Service
//
// Pāḷi has no native TTS voice, but Kannada is phonetic and covers the
// same sounds (ā ī ū ṃ ṅ ñ ṇ ṭ ḍ ḷ ...), so we transliterate Pāḷi Roman
// into Kannada script and speak it with the Kannada ("kn-IN") voice.
// Example: "Buddhaṃ saraṇaṃ gacchāmi" -> "ಬುದ್ಧಂ ಸರಣಂ ಗಚ್ಛಾಮಿ".
class TtsService {
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _isInit = false;

  static Future<void> init() async {
    if (!_isInit) {
      await _flutterTts.setLanguage(
        "kn-IN",
      ); // Kannada voice for Pali pronunciation
      await _flutterTts.setSpeechRate(0.45); // Slightly slower for clarity
      await _flutterTts.setPitch(1.0);
      _isInit = true;
    }
  }

  /// Speaks a Pāḷi Roman line by converting it to Kannada script first.
  static Future<void> speakPali(String paliRoman) async {
    await init();
    final kannadaText = paliRomanToKannada(paliRoman);
    if (kannadaText.isNotEmpty) {
      await _flutterTts.stop();
      await _flutterTts.setLanguage("kn-IN");
      await _flutterTts.speak(kannadaText);
    }
  }

  static Future<void> speak(String text) async {
    await init();
    if (text.isNotEmpty) {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    }
  }

  static Future<void> stop() async {
    await _flutterTts.stop();
  }
}

class LanguageModeSwitcher extends StatelessWidget {
  final AppLanguage currentLang;
  final VoidCallback onLanguageToggle;

  const LanguageModeSwitcher({
    super.key,
    required this.currentLang,
    required this.onLanguageToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isMm = currentLang == AppLanguage.myanmar;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        avatar: Icon(
          Icons.language,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
        label: Text(
          isMm ? 'မြန်မာ' : 'ENG',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        selected: false,
        onSelected: (_) => onLanguageToggle(),
      ),
    );
  }
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
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

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

class VocabularyQuizScreen extends StatefulWidget {
  final List<VocabItem> words;
  final bool isMyanmar;

  const VocabularyQuizScreen({
    super.key,
    required this.words,
    required this.isMyanmar,
  });

  @override
  State<VocabularyQuizScreen> createState() => _VocabularyQuizScreenState();
}

class _VocabularyQuizScreenState extends State<VocabularyQuizScreen> {
  int _questionIndex = 0;
  int _score = 0;
  int? _selectedIndex;

  void _selectAnswer(int index) {
    if (_selectedIndex != null) return;
    setState(() {
      _selectedIndex = index;
      final choiceCount = widget.words.length < 4 ? widget.words.length : 4;
      if (choiceCount > 0 && index == _questionIndex % choiceCount) _score++;
    });
  }

  void _nextQuestion() {
    setState(() {
      _questionIndex++;
      _selectedIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMm = widget.isMyanmar;
    final totalQuestions = widget.words.length < 10 ? widget.words.length : 10;
    final completed = _questionIndex >= totalQuestions;
    final question = completed ? null : widget.words[_questionIndex];
    final choiceCount = widget.words.length < 4 ? widget.words.length : 4;
    final answerPosition = choiceCount == 0 ? 0 : _questionIndex % choiceCount;
    final choices = List<VocabItem>.generate(choiceCount, (index) {
      final offset = (index - answerPosition + choiceCount) % choiceCount;
      return widget.words[(_questionIndex + offset) % widget.words.length];
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(isMm ? 'အခန်းလေ့ကျင့်ခန်း' : 'Chapter Practice'),
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
                Text(
                  isMm ? question!.paliMm : question!.paliRoman,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isMm
                      ? 'မှန်ကန်သော အဓိပ္ပာယ်ကို ရွေးပါ'
                      : 'Choose the correct meaning',
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
                              ? 'အဖြေမှန်: ${question.translateMm}'
                              : 'Correct: ${question.translateEn}'),
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
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return [];

    return _allWords()
        .where(
          (result) => [
            result.item.paliMm,
            result.item.paliRoman,
            result.item.translateMm,
            result.item.translateEn,
          ].any((value) => value.toLowerCase().contains(normalizedQuery)),
        )
        .toList();
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

    return ListView.builder(
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
                  final next = Set<String>.from(selected);
                  if (value == true) {
                    next.add(category.id);
                  } else {
                    next.remove(category.id);
                  }
                  _setDailyLearningCategories(next);
                },
              ),
          ],
        ),
        const Divider(height: 32),
        Text(
          isMm ? 'ဒေတာ' : 'Data',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
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
                  Icon(
                    Icons.menu_book_rounded,
                    size: 38,
                    color: Theme.of(context).colorScheme.onPrimary,
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
                              ? 'PaliMala သည် ပါဠိဘာသာကို အခြေခံမှစ၍ အဆင့်လိုက် လေ့လာနိုင်ရန် ရည်ရွယ်ထားသော ပညာရေးအက်ပ်ဖြစ်ပါသည်။ သင်ခန်းစာများနှင့် လက်တွေ့အသုံးချစကားလုံးများကို မြန်မာနှင့် အင်္ဂလိပ်ဘာသာဖြင့် လေ့လာနိုင်ပါသည်။'
                              : 'PaliMala is an educational app for learning Pāḷi step by step, with lessons and practical vocabulary available in Myanmar and English.',
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
            title: Text(
              titles[selectedIndex],
              style: const TextStyle(fontWeight: FontWeight.bold),
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
              ? _buildSavedWords(isMm)
              : _buildSettings(isMm),
        );
      },
    );
  }
}

// 2. SubCategory List Screen
class SubCategoryScreen extends StatefulWidget {
  final MainCategory category;
  final AppLanguage currentLang;
  final VoidCallback onLanguageToggle;
  final Set<String> savedWords;
  final ValueChanged<VocabItem> onSavedWordToggle;

  const SubCategoryScreen({
    super.key,
    required this.category,
    required this.currentLang,
    required this.onLanguageToggle,
    required this.savedWords,
    required this.onSavedWordToggle,
  });

  @override
  State<SubCategoryScreen> createState() => _SubCategoryScreenState();
}

class _SubCategoryScreenState extends State<SubCategoryScreen> {
  late AppLanguage _currentLang;

  @override
  void initState() {
    super.initState();
    _currentLang = widget.currentLang;
  }

  void _toggleLanguage() {
    setState(() {
      _currentLang = _currentLang == AppLanguage.myanmar
          ? AppLanguage.english
          : AppLanguage.myanmar;
    });
    widget.onLanguageToggle();
  }

  @override
  Widget build(BuildContext context) {
    bool isMm = _currentLang == AppLanguage.myanmar;

    return Scaffold(
      appBar: AppBar(
        title: Text(isMm ? widget.category.titleMm : widget.category.titleEn),
        actions: [
          LanguageModeSwitcher(
            currentLang: _currentLang,
            onLanguageToggle: _toggleLanguage,
          ),
        ],
      ),
      body: widget.category.subCategories.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isMm
                          ? 'ဤအမျိုးအစားတွင် သင်ခန်းစာ မရှိသေးပါ။'
                          : 'No lessons in this category yet.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: widget.category.subCategories.length,
              itemBuilder: (context, index) {
                final subCat = widget.category.subCategories[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .secondaryContainer,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: isMm ? null : 'SourceSans3',
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ),
                    ),
                    title: Text(
                      isMm ? subCat.titleMm : subCat.titleEn,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 18,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailContentScreen(
                            subCategory: subCat,
                            currentLang: _currentLang,
                            onLanguageToggle: widget.onLanguageToggle,
                            savedWords: widget.savedWords,
                            onSavedWordToggle: widget.onSavedWordToggle,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

// 3. Detail Content Screen (Lists Vocab or Dialogues)
class DetailContentScreen extends StatefulWidget {
  final SubCategory subCategory;
  final AppLanguage currentLang;
  final VoidCallback onLanguageToggle;
  final Set<String> savedWords;
  final ValueChanged<VocabItem> onSavedWordToggle;

  const DetailContentScreen({
    super.key,
    required this.subCategory,
    required this.currentLang,
    required this.onLanguageToggle,
    required this.savedWords,
    required this.onSavedWordToggle,
  });

  @override
  State<DetailContentScreen> createState() => _DetailContentScreenState();
}

class _DetailContentScreenState extends State<DetailContentScreen> {
  late AppLanguage _currentLang;

  @override
  void initState() {
    super.initState();
    _currentLang = widget.currentLang;
  }

  void _toggleLanguage() {
    setState(() {
      _currentLang = _currentLang == AppLanguage.myanmar
          ? AppLanguage.english
          : AppLanguage.myanmar;
    });
    widget.onLanguageToggle();
  }

  @override
  Widget build(BuildContext context) {
    bool isMm = _currentLang == AppLanguage.myanmar;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMm ? widget.subCategory.titleMm : widget.subCategory.titleEn,
        ),
        actions: [
          LanguageModeSwitcher(
            currentLang: _currentLang,
            onLanguageToggle: _toggleLanguage,
          ),
        ],
      ),
      body: _buildChapterContent(context, isMm),
    );
  }

  Widget _buildChapterContent(BuildContext context, bool isMm) {
    final practiceWords =
        widget.subCategory.vocabList ??
        widget.subCategory.dialogueList
            ?.map(
              (dialogue) => VocabItem(
                paliMm: dialogue.paliMm,
                paliRoman: dialogue.paliRoman,
                translateMm: dialogue.translateMm,
                translateEn: dialogue.translateEn,
              ),
            )
            .toList() ??
        const <VocabItem>[];

    return Column(
      children: [
        if (practiceWords.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
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
                icon: const Icon(Icons.quiz_rounded),
                label: Text(
                  isMm ? 'ဤအခန်းကို လေ့ကျင့်မည်' : 'Practice this chapter',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(15),
                ),
              ),
            ),
          ),
        Expanded(
          child: widget.subCategory.story != null
              ? _buildStory(context)
              : widget.subCategory.dialogueList != null
              ? _buildDialogueList(context, isMm)
              : _buildVocabList(context, isMm),
        ),
      ],
    );
  }

  Widget _buildStory(BuildContext context) {
    final story = widget.subCategory.story!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    String join(String Function(StorySentence) field) =>
        story.sentences.map(field).join(' ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Card(
          color: colors.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ပုံပြင်အပြည့်အစုံ · Full story',
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SelectableText(
                  join((sentence) => sentence.paliMm),
                  style: textTheme.titleLarge?.copyWith(
                    height: 1.8,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  join((sentence) => sentence.paliRoman),
                  style: textTheme.bodyLarge?.copyWith(
                    height: 1.65,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const Divider(height: 28),
                SelectableText(
                  join((sentence) => sentence.translateMm),
                  style: textTheme.bodyLarge?.copyWith(height: 1.8),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  join((sentence) => sentence.translateEn),
                  style: textTheme.bodyLarge?.copyWith(height: 1.65),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Text(
            'စာကြောင်းအလိုက် · Sentence by sentence',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        for (var index = 0; index < story.sentences.length; index++)
          _buildStorySentenceCard(context, story.sentences[index], index),
      ],
    );
  }

  Widget _buildStorySentenceCard(
    BuildContext context,
    StorySentence sentence,
    int index,
  ) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    Widget line(String label, String value, {bool primary = false}) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            value,
            style: textTheme.bodyLarge?.copyWith(
              height: 1.65,
              color: primary ? colors.primary : colors.onSurface,
              fontWeight: primary ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}',
              style: textTheme.labelLarge?.copyWith(color: colors.secondary),
            ),
            line('ပါဠိ · Pāḷi', sentence.paliMm, primary: true),
            line('Roman Pāḷi', sentence.paliRoman),
            line('မြန်မာဘာသာပြန် · Burmese', sentence.translateMm),
            line('English translation', sentence.translateEn),
          ],
        ),
      ),
    );
  }

  Widget _buildVocabList(BuildContext context, bool isMm) {
    final list = widget.subCategory.vocabList ?? [];
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMm ? item.paliMm : item.paliRoman,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isMm ? item.translateMm : item.translateEn,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: widget.savedWords.contains(item.paliRoman)
                          ? (isMm ? 'မှတ်ထားမှုမှ ဖယ်ရန်' : 'Remove saved word')
                          : (isMm ? 'သိမ်းရန်' : 'Save word'),
                      icon: Icon(
                        widget.savedWords.contains(item.paliRoman)
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                      ),
                      onPressed: () {
                        widget.onSavedWordToggle(item);
                        setState(() {});
                      },
                    ),
                    IconButton.filledTonal(
                      tooltip: isMm ? 'အသံနားထောင်ရန်' : 'Listen',
                      icon: const Icon(Icons.volume_up_rounded),
                      onPressed: () {
                        TtsService.speakPali(item.paliRoman);
                      },
                    ),
                  ],
                ),
                if (item.example != null) ...[
                  const Divider(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMm
                                  ? item.example!.paliMm
                                  : item.example!.paliRoman,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isMm
                                  ? item.example!.translateMm
                                  : item.example!.translateEn,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: isMm
                            ? 'စာကြောင်းအသံနားထောင်ရန်'
                            : 'Listen to sentence',
                        icon: const Icon(Icons.volume_up_rounded),
                        onPressed: () {
                          TtsService.speakPali(item.example!.paliRoman);
                        },
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogueList(BuildContext context, bool isMm) {
    final list = widget.subCategory.dialogueList ?? [];
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final dialogue = list[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Chip(
                      label: Text(
                        isMm ? dialogue.speakerMm : dialogue.speakerEn,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.mic_rounded,
                        color: Colors.deepOrange,
                      ),
                      onPressed: () {
                        TtsService.speakPali(dialogue.paliRoman);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isMm ? dialogue.paliMm : dialogue.paliRoman,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isMm ? dialogue.translateMm : dialogue.translateEn,
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// 4. Example Sentence Detail Screen

// 5. Data download sheet
//
// Opened from Settings. Lists every downloadable data set together with its
// published hash and lets the user download or update only the chapters they
// need. The auto-update switch lives here as well.
class DataDownloadSheet extends StatefulWidget {
  final bool isMyanmar;

  const DataDownloadSheet({super.key, required this.isMyanmar});

  @override
  State<DataDownloadSheet> createState() => _DataDownloadSheetState();
}

class _DataDownloadSheetState extends State<DataDownloadSheet> {
  final Set<String> _busy = <String>{};
  bool _checking = false;
  bool _downloadingAll = false;

  Future<void> _checkForUpdates() async {
    final messenger = ScaffoldMessenger.of(context);
    final isMm = widget.isMyanmar;
    setState(() => _checking = true);
    try {
      await AppDataRepository.checkForUpdates();
      final updates = AppDataRepository.updatesAvailable;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            updates == 0
                ? (isMm
                      ? 'ဒေတာအားလုံး နောက်ဆုံးဖြစ်သည်'
                      : 'All data is up to date')
                : (isMm
                      ? 'မွမ်းမံရန် $updates ခု ရှိသည်'
                      : '$updates update(s) available'),
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(isMm ? 'စစ်ဆေး၍ မရပါ: $error' : 'Check failed: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _download(DatasetInfo dataset) async {
    if (_busy.contains(dataset.id)) return;
    final messenger = ScaffoldMessenger.of(context);
    final isMm = widget.isMyanmar;
    setState(() => _busy.add(dataset.id));
    try {
      final updated = await AppDataRepository.downloadDataset(dataset);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            updated
                ? (isMm
                      ? '${dataset.titleMm} ကို ရယူပြီးပါပြီ'
                      : 'Downloaded ${dataset.titleEn}')
                : (isMm
                      ? '${dataset.titleMm} နောက်ဆုံးဖြစ်နေပါသည်'
                      : '${dataset.titleEn} is already up to date'),
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(isMm ? 'ရယူ၍ မရပါ: $error' : 'Download failed: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(dataset.id));
    }
  }

  Future<void> _downloadAll() async {
    final messenger = ScaffoldMessenger.of(context);
    final isMm = widget.isMyanmar;
    setState(() => _downloadingAll = true);
    try {
      final updated = await AppDataRepository.downloadAllUpdates();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? 'ဒေတာ $updated ခု မွမ်းမံပြီးပါပြီ'
                : 'Updated $updated data set(s)',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? 'ဒေတာအချို့ကို မွမ်းမံ၍ မရပါ: $error'
                : 'Some datasets could not be updated: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _downloadingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMm = widget.isMyanmar;
    final theme = Theme.of(context);
    final datasets = AppDataRepository.datasets;
    final updates = AppDataRepository.updatesAvailable;
    final busy = _checking || _downloadingAll || _busy.isNotEmpty;

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMm ? 'ဒေတာ ဒေါင်းလုဒ်' : 'Data downloads',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isMm
                        ? 'လိုအပ်သော အခန်းများကို ရွေးချယ်ရယူနိုင်ပါသည်။ ဖိုင်တစ်ခုစီကို အလိုအလျောက် စစ်ဆေးပါသည်။'
                        : 'Download only the chapters you need. Every file is verified automatically.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              secondary: const Icon(Icons.cloud_sync_outlined),
              title: Text(isMm ? 'အလိုလျောက် မွမ်းမံရန်' : 'Auto update'),
              subtitle: Text(
                isMm
                    ? 'အက်ပ်ဖွင့်ချိန်တွင် အလိုလျောက် ရယူပါမည်'
                    : 'Fetch newer data automatically on launch',
              ),
              value: AppDataRepository.autoUpdateEnabled,
              onChanged: (value) async {
                await AppDataRepository.setAutoUpdate(value);
                if (!mounted) return;
                setState(() {});
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _checking ? null : _checkForUpdates,
                      icon: _checking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(
                        isMm ? 'အသစ် စစ်ဆေးရန်' : 'Check for updates',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (updates == 0 || busy) ? null : _downloadAll,
                      icon: _downloadingAll
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(isMm ? 'အားလုံး ရယူရန်' : 'Download all'),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: datasets.isEmpty
                  ? Center(
                      child: Text(isMm ? 'ဒေတာ မတွေ့ပါ' : 'No datasets found'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: datasets.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) =>
                          _buildDatasetTile(datasets[index], isMm),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatasetTile(DatasetInfo dataset, bool isMm) {
    final theme = Theme.of(context);
    final isUpToDate =
        AppDataRepository.statusOf(dataset) == DatasetStatus.upToDate;
    final isBusy = _busy.contains(dataset.id);
    final actionLabel = AppDataRepository.hasDownloadedCopy(dataset)
        ? (isMm ? 'မွမ်းမံရန်' : 'Update')
        : (isMm ? 'ရယူရန်' : 'Download');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Icon(
          dataset.icon,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(
        isMm ? dataset.titleMm : dataset.titleEn,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isUpToDate
                ? (isMm ? 'နောက်ဆုံးဖြစ်သည်' : 'Up to date')
                : (isMm ? 'မွမ်းမံရန် ရှိသည်' : 'Update available'),
            style: TextStyle(
              color: isUpToDate
                  ? Colors.green.shade700
                  : theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      trailing: isUpToDate
          ? const Icon(Icons.check_circle_rounded, color: Colors.green)
          : isBusy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : FilledButton.tonal(
              onPressed: () => _download(dataset),
              child: Text(actionLabel),
            ),
      onTap: isUpToDate || isBusy ? null : () => _download(dataset),
    );
  }
}
