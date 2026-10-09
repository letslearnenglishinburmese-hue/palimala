import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_data.dart';
import 'pali_transliteration.dart';

late List<MainCategory> appData;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  appData = await AppDataRepository.load();
  runApp(const PaliLearningApp());
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
    _loadSavedWords();
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
    _selectedTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pāḷi Learning App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8C1D11),
          primary: const Color(0xFF8C1D11),
          secondary: const Color(0xFFD97706),
          surface: const Color(0xFFFDFBF7),
        ),
        fontFamily: 'Pyidaungsu Numbers',
        fontFamilyFallback: const ['Pyidaungsu', 'GentiumPlus', 'SourceSans3'],
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8C1D11),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Pyidaungsu Numbers',
        fontFamilyFallback: const ['Pyidaungsu', 'GentiumPlus', 'SourceSans3'],
      ),
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
            backgroundColor: _isDarkMode
                ? const Color(0xFF302925)
                : const Color(0xFFF1E9DF),
            indicatorColor: Theme.of(context).colorScheme.primary
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
  final String searchText;

  const _SearchWordResult({
    required this.item,
    required this.category,
    required this.subCategory,
    required this.searchText,
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

class _DashboardStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _DashboardStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleLarge),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late final List<_SearchWordResult> _wordIndex;

  @override
  void initState() {
    super.initState();
    _wordIndex = [
      for (final category in appData)
        for (final subCategory in category.subCategories)
          for (final item in subCategory.vocabList ?? [])
            _SearchWordResult(
              item: item,
              category: category,
              subCategory: subCategory,
              searchText:
                  '${item.paliMm}\n${item.paliRoman}\n'
                          '${item.translateMm}\n${item.translateEn}'
                      .toLowerCase(),
            ),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_SearchWordResult> _findWords(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return [];

    return _wordIndex
        .where((result) => result.searchText.contains(normalizedQuery))
        .toList();
  }

  List<_SearchWordResult> _allWords() {
    return _wordIndex;
  }

  Widget _buildHome(bool isMm) {
    final words = _allWords();
    final today = DateTime.now();
    final dayIndex =
        today.difference(DateTime(today.year)).inDays % words.length;
    final dailyWord = words[dayIndex].item;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF762319), Color(0xFF9A4329), Color(0xFFB96A36)],
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
                    onPressed: () => TtsService.speakPali(dailyWord.paliRoman),
                    color: Colors.white,
                    icon: const Icon(Icons.volume_up_rounded),
                  ),
                  IconButton(
                    tooltip: widget.savedWords.contains(dailyWord.paliRoman)
                        ? (isMm ? 'သိမ်းထားမှုမှ ဖယ်ရန်' : 'Remove saved word')
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
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _DashboardStat(
                icon: Icons.menu_book_rounded,
                value: '${words.length}',
                label: isMm ? 'ဝေါဟာရ' : 'Vocabulary',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DashboardStat(
                icon: Icons.bookmark_rounded,
                value: '${widget.savedWords.length}',
                label: isMm ? 'သိမ်းထားသည်' : 'Saved words',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
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
            final columns = constraints.maxWidth >= 600 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: appData.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.12,
              ),
              itemBuilder: (context, index) {
                final category = appData[index];
                final wordCount = category.subCategories.fold<int>(
                  0,
                  (total, subCategory) =>
                      total + (subCategory.vocabList?.length ?? 0),
                );
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
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            category.icon,
                            size: 28,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: FittedBox(
                                  alignment: Alignment.centerLeft,
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    isMm ? category.titleMm : category.titleEn,
                                    maxLines: 1,
                                    softWrap: false,
                                    overflow: TextOverflow.visible,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isMm ? '$wordCount လုံး' : '$wordCount words',
                                style: Theme.of(context).textTheme.bodySmall,
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
      ],
    );
  }

  Widget _buildDrawer(BuildContext context, bool isMm) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/palimala_logo.png',
                    width: 96,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ပါဠိမာလာ',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pāḷimālā',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary
                            .withValues(alpha: 0.86),
                        fontFamily: 'GentiumPlus',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text(isMm ? 'အက်ပ်အကြောင်း' : 'About app'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(isMm ? 'အက်ပ်အကြောင်း' : 'About app'),
                  content: Text(
                    isMm
                        ? 'ဒီအက်ပ်သည် ပါဠိဘာသာစကားကို သင်ယူရန်အတွက် အခြေခံ vocabularies၊ အခြေခံအလေ့အကျင့်များနှင့် စကားဝိုင်းပုံစံအဓိကအချက်များကို တစ်နေရာတည်းတွင် စုစည်းထားသော လက်စွဲတစ်ခုဖြစ်ပါသည်။'
                        : 'This app is a compact Pāḷi learning guide designed to help learners study vocabulary, example phrases, and simple conversational expressions in one place.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
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
                builder: (context) => AlertDialog(
                  title: Text(isMm ? 'ဆက်သွယ်ရန်' : 'Contact'),
                  content: Text(
                    isMm
                        ? 'အက်ပ်နှင့်ပတ်သက်၍ မေးမြန်းလိုပါက support@palimala.app သို့ အီးမေးလ်ပို့နိုင်ပါသည်။'
                        : 'For app questions or feedback, please contact support@palimala.app.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
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
      body: ListView.builder(
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
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              title: Text(
                isMm ? subCat.titleMm : subCat.titleEn,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
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
          child: widget.subCategory.dialogueList != null
              ? _buildDialogueList(context, isMm)
              : _buildVocabList(context, isMm),
        ),
      ],
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
