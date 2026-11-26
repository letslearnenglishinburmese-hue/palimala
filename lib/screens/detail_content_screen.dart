import 'dart:async';

import 'package:flutter/material.dart';
import '../app_data.dart';
import '../main.dart' show AppLanguage;
import '../services/tts_service.dart';
import '../widgets/language_mode_switcher.dart';
import '../widgets/word_share_dialog.dart';
import 'flashcard_screen.dart';
import 'vocabulary_quiz_screen.dart';

// Detail Content Screen (Lists Vocab, Dialogues or Story)
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
  bool _warnedMissingVoice = false;

  // Study Mode (hide/reveal meanings)
  bool _hideMeanings = false;
  final Set<int> _revealedIndices = {};

  // Auto-Play Playlist state
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};
  bool _isAutoPlaying = false;
  bool _isAutoPlayPaused = false;
  int? _activePlayIndex;
  String _activePlayPhase = 'word'; // 'word' or 'example'
  bool _includeExamplesInAutoPlay = true;
  int _autoPlaySessionId = 0;

  @override
  void initState() {
    super.initState();
    _currentLang = widget.currentLang;
  }

  @override
  void dispose() {
    _autoPlaySessionId++;
    _scrollController.dispose();
    if (_isAutoPlaying || TtsService.isSpeaking.value) {
      unawaited(TtsService.stop());
    }
    super.dispose();
  }

  List<({String wordRoman, String wordMm, String? exampleRoman})>
  get _playableItems {
    final vocab = widget.subCategory.vocabList;
    if (vocab != null && vocab.isNotEmpty) {
      return [
        for (final item in vocab)
          (
            wordRoman: item.paliRoman,
            wordMm: item.paliMm,
            exampleRoman: item.example?.paliRoman,
          ),
      ];
    }
    final dialogues = widget.subCategory.dialogueList;
    if (dialogues != null && dialogues.isNotEmpty) {
      return [
        for (final d in dialogues)
          (
            wordRoman: d.paliRoman,
            wordMm: d.paliMm,
            exampleRoman: null,
          ),
      ];
    }
    return const [];
  }

  Future<void> _speakWithCheck(String paliRoman, bool isMm) async {
    await TtsService.speakPali(paliRoman);
    if (!mounted || _warnedMissingVoice) return;
    final available = await TtsService.isVoiceAvailable();
    if (!available && mounted) {
      _warnedMissingVoice = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? 'ဖုန်းတွင် ပါဠိအသံထွက် (Kannada kn-IN TTS) ထည့်သွင်းထားခြင်း မရှိသေးပါ။'
                : 'Kannada (kn-IN) TTS voice is not installed on this device for Pāḷi audio.',
          ),
        ),
      );
    }
  }

  void _startAutoPlay({int startIndex = 0}) {
    final items = _playableItems;
    if (items.isEmpty) return;
    final clampedIndex = startIndex.clamp(0, items.length - 1);
    _autoPlaySessionId++;
    final sessionId = _autoPlaySessionId;
    setState(() {
      _isAutoPlaying = true;
      _isAutoPlayPaused = false;
      _activePlayIndex = clampedIndex;
      _activePlayPhase = 'word';
    });
    unawaited(_runAutoPlayLoop(clampedIndex, sessionId));
  }

  Future<void> _runAutoPlayLoop(int startIndex, int sessionId) async {
    final items = _playableItems;
    for (var i = startIndex; i < items.length; i++) {
      if (!mounted ||
          _autoPlaySessionId != sessionId ||
          !_isAutoPlaying ||
          _isAutoPlayPaused) {
        return;
      }

      setState(() {
        _activePlayIndex = i;
        _activePlayPhase = 'word';
      });
      _scrollToIndex(i);

      final item = items[i];
      await TtsService.speakPaliAndWait(item.wordRoman);
      if (!mounted ||
          _autoPlaySessionId != sessionId ||
          !_isAutoPlaying ||
          _isAutoPlayPaused) {
        return;
      }

      final exampleRoman = item.exampleRoman;
      if (_includeExamplesInAutoPlay &&
          exampleRoman != null &&
          exampleRoman.trim().isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (!mounted ||
            _autoPlaySessionId != sessionId ||
            !_isAutoPlaying ||
            _isAutoPlayPaused) {
          return;
        }
        setState(() {
          _activePlayPhase = 'example';
        });
        await TtsService.speakPaliAndWait(exampleRoman);
        if (!mounted ||
            _autoPlaySessionId != sessionId ||
            !_isAutoPlaying ||
            _isAutoPlayPaused) {
          return;
        }
      }

      await Future<void>.delayed(const Duration(milliseconds: 600));
    }

    if (!mounted || _autoPlaySessionId != sessionId) return;
    setState(() {
      _isAutoPlaying = false;
      _isAutoPlayPaused = false;
      _activePlayIndex = null;
      _activePlayPhase = 'word';
    });
  }

  Future<void> _pauseAutoPlay() async {
    _autoPlaySessionId++;
    setState(() {
      _isAutoPlayPaused = true;
    });
    await TtsService.stop();
  }

  void _resumeAutoPlay() {
    if (!_isAutoPlaying) {
      _startAutoPlay(startIndex: _activePlayIndex ?? 0);
      return;
    }
    _autoPlaySessionId++;
    final sessionId = _autoPlaySessionId;
    final index = _activePlayIndex ?? 0;
    setState(() {
      _isAutoPlayPaused = false;
    });
    unawaited(_runAutoPlayLoop(index, sessionId));
  }

  Future<void> _stopAutoPlay() async {
    _autoPlaySessionId++;
    setState(() {
      _isAutoPlaying = false;
      _isAutoPlayPaused = false;
      _activePlayIndex = null;
      _activePlayPhase = 'word';
    });
    await TtsService.stop();
  }

  Future<void> _skipAutoPlay(int delta) async {
    final items = _playableItems;
    if (items.isEmpty) return;
    final current = _activePlayIndex ?? 0;
    final target = (current + delta).clamp(0, items.length - 1);
    _autoPlaySessionId++;
    await TtsService.stop();
    if (!mounted) return;
    if (_isAutoPlayPaused) {
      setState(() {
        _activePlayIndex = target;
        _activePlayPhase = 'word';
      });
      _scrollToIndex(target);
    } else {
      _startAutoPlay(startIndex: target);
    }
  }

  void _scrollToIndex(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _itemKeys[index];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.2,
        );
      } else if (_scrollController.hasClients) {
        final estimated = (index * 165.0).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.animateTo(
          estimated,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
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
    final hasVocabOrDialogue = _playableItems.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMm ? widget.subCategory.titleMm : widget.subCategory.titleEn,
        ),
        actions: [
          if (hasVocabOrDialogue)
            IconButton(
              tooltip: _hideMeanings
                  ? (isMm ? 'အဓိပ္ပာယ်များ ပြန်ပြရန်' : 'Show meanings')
                  : (isMm
                        ? 'အဓိပ္ပာယ်ဖွက်ရန် (Study Mode)'
                        : 'Hide meanings (Study Mode)'),
              icon: Icon(
                _hideMeanings
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_outlined,
                color: _hideMeanings
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              onPressed: () {
                setState(() {
                  _hideMeanings = !_hideMeanings;
                  _revealedIndices.clear();
                });
              },
            ),
          ValueListenableBuilder<bool>(
            valueListenable: TtsService.isSpeaking,
            builder: (context, speaking, child) {
              if (!speaking && !_isAutoPlaying) return const SizedBox.shrink();
              return IconButton(
                tooltip: isMm ? 'အသံရပ်ရန်' : 'Stop audio',
                icon: const Icon(Icons.stop_circle_outlined),
                onPressed: _isAutoPlaying ? _stopAutoPlay : TtsService.stop,
              );
            },
          ),
          LanguageModeSwitcher(
            currentLang: _currentLang,
            onLanguageToggle: _toggleLanguage,
          ),
        ],
      ),
      body: _buildChapterContent(context, isMm),
      bottomNavigationBar: _isAutoPlaying
          ? _buildMiniPlayerBar(context, isMm)
          : null,
    );
  }

  Widget _buildMiniPlayerBar(BuildContext context, bool isMm) {
    final items = _playableItems;
    final index = (_activePlayIndex ?? 0).clamp(0, items.length - 1);
    final current = items.isEmpty ? null : items[index];
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      elevation: 10,
      color: colors.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    _isAutoPlayPaused
                        ? Icons.pause_circle_filled_rounded
                        : Icons.graphic_eq_rounded,
                    color: colors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          current == null
                              ? ''
                              : (isMm ? current.wordMm : current.wordRoman),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                        Text(
                          '${index + 1}/${items.length} · ${_activePlayPhase == 'example' ? (isMm ? 'နမူနာဝါကျ' : 'Example') : (isMm ? 'စကားလုံး' : 'Word')}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: isMm ? 'အရင်စကားလုံး' : 'Previous',
                    icon: const Icon(Icons.skip_previous_rounded),
                    onPressed: index > 0 ? () => _skipAutoPlay(-1) : null,
                  ),
                  IconButton.filled(
                    tooltip: _isAutoPlayPaused
                        ? (isMm ? 'ဆက်ဖွင့်ရန်' : 'Resume')
                        : (isMm ? 'ခေတ္တရပ်ရန်' : 'Pause'),
                    icon: Icon(
                      _isAutoPlayPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                    ),
                    onPressed:
                        _isAutoPlayPaused ? _resumeAutoPlay : _pauseAutoPlay,
                  ),
                  IconButton(
                    tooltip: isMm ? 'နောက်စကားလုံး' : 'Next',
                    icon: const Icon(Icons.skip_next_rounded),
                    onPressed: index + 1 < items.length
                        ? () => _skipAutoPlay(1)
                        : null,
                  ),
                  IconButton(
                    tooltip: isMm ? 'ပိတ်ရန်' : 'Stop',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _stopAutoPlay,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  FilterChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      isMm ? 'ဝါကျပါ ဖတ်မည်' : '+ Examples',
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: _includeExamplesInAutoPlay,
                    onSelected: (value) {
                      setState(() {
                        _includeExamplesInAutoPlay = value;
                      });
                    },
                  ),
                  const Spacer(),
                  for (final rate in [0.3, 0.45, 0.6])
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          '${rate}x',
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: (TtsService.speechRate - rate).abs() < 0.05,
                        onSelected: (selected) async {
                          if (!selected) return;
                          await TtsService.setSpeechRate(rate);
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
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
                        icon: const Icon(Icons.quiz_rounded),
                        label: Text(
                          isMm
                              ? 'ဤအခန်းကို လေ့ကျင့်မည်'
                              : 'Practice this chapter',
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => FlashcardScreen(
                            words: practiceWords,
                            isMyanmar: isMm,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.flip_to_back_rounded),
                      label: const Text('Flashcard'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      tooltip: isMm
                          ? 'အသံနားထောင် လေ့ကျင့်ခန်း'
                          : 'Listening quiz',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => VocabularyQuizScreen(
                            words: practiceWords,
                            isMyanmar: isMm,
                            isListeningMode: true,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.hearing_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isAutoPlaying
                      ? (_isAutoPlayPaused ? _resumeAutoPlay : _pauseAutoPlay)
                      : () => _startAutoPlay(),
                  icon: Icon(
                    _isAutoPlaying && !_isAutoPlayPaused
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                  ),
                  label: Text(
                    _isAutoPlaying && !_isAutoPlayPaused
                        ? (isMm
                              ? 'Auto-Play ဖွင့်နေသည် (ခေတ္တရပ်ရန်)'
                              : 'Auto-Playing (Tap to pause)')
                        : (isMm
                              ? 'တစ်ခန်းလုံး နားထောင်မည် (Auto-Play)'
                              : 'Auto-Play Chapter Audio'),
                  ),
                ),
              ],
            ),
          ),
        if (widget.subCategory.descriptionMm != null ||
            widget.subCategory.descriptionEn != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Card(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  isMm
                      ? widget.subCategory.descriptionMm ??
                            widget.subCategory.descriptionEn!
                      : widget.subCategory.descriptionEn ??
                            widget.subCategory.descriptionMm!,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(height: 1.6),
                ),
              ),
            ),
          ),
        Expanded(
          child: widget.subCategory.story != null
              ? _buildStory(context, isMm)
              : widget.subCategory.dialogueList != null
              ? _buildDialogueList(context, isMm)
              : _buildVocabList(context, isMm),
        ),
      ],
    );
  }

  Widget _buildStory(BuildContext context, bool isMm) {
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
                const SizedBox(height: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: TtsService.isSpeaking,
                  builder: (context, speaking, child) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => _speakWithCheck(
                            join((sentence) => sentence.paliRoman),
                            isMm,
                          ),
                          icon: const Icon(Icons.volume_up_rounded),
                          label: const Text(
                            'တစ်ပုဒ်လုံး နားထောင်ရန် · Play full story',
                          ),
                        ),
                        if (speaking)
                          OutlinedButton.icon(
                            onPressed: () => TtsService.stop(),
                            icon: const Icon(Icons.stop_rounded),
                            label: Text(isMm ? 'ရပ်ရန်' : 'Stop'),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                SelectableText(
                  join(
                    (sentence) => isMm ? sentence.paliMm : sentence.paliRoman,
                  ),
                  style: textTheme.titleLarge?.copyWith(
                    height: 1.8,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const Divider(height: 28),
                SelectableText(
                  join(
                    (sentence) =>
                        isMm ? sentence.translateMm : sentence.translateEn,
                  ),
                  style: textTheme.bodyLarge?.copyWith(height: 1.8),
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
          _buildStorySentenceCard(context, story.sentences[index], index, isMm),
      ],
    );
  }

  Widget _buildStorySentenceCard(
    BuildContext context,
    StorySentence sentence,
    int index,
    bool isMm,
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${index + 1}',
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.secondary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip:
                      'ဤစာကြောင်းကို နားထောင်ရန် · Listen to this sentence',
                  icon: const Icon(Icons.volume_up_rounded),
                  onPressed: () => TtsService.speakPali(sentence.paliRoman),
                ),
              ],
            ),
            line(
              isMm ? 'ပါဠိ' : 'Roman Pāḷi',
              isMm ? sentence.paliMm : sentence.paliRoman,
              primary: true,
            ),
            line(
              isMm ? 'မြန်မာဘာသာပြန်' : 'English translation',
              isMm ? sentence.translateMm : sentence.translateEn,
            ),
          ],
        ),
      ),
    );
  }

  String? _extractPosTag(String paliRoman, bool isMm) {
    final upper = paliRoman.toUpperCase();
    if (upper.contains('(M)')) return isMm ? 'ပုလ္လိင်' : 'Masc.';
    if (upper.contains('(F)')) return isMm ? 'ဣတ္ထိလိင်' : 'Fem.';
    if (upper.contains('(N)')) return isMm ? 'နပုလ္လိင်' : 'Neut.';
    if (upper.contains('(V)')) return isMm ? 'ကြိယာ' : 'Verb';
    if (upper.contains('(IND)')) return isMm ? 'နိပါတ်' : 'Indecl.';
    return null;
  }

  Widget _buildHighlightedExampleText({
    required String sentence,
    required String rawKeyword,
    required TextStyle baseStyle,
    required TextStyle highlightStyle,
  }) {
    final cleanKeyword = rawKeyword
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .trim();
    if (cleanKeyword.isEmpty) {
      return Text(sentence, style: baseStyle);
    }

    final lowerSentence = sentence.toLowerCase();
    final lowerKey = cleanKeyword.toLowerCase();

    var matchStart = lowerSentence.indexOf(lowerKey);
    var matchLength = lowerKey.length;

    // Fallback to stem prefix match (for declined/conjugated inflections)
    if (matchStart < 0 && lowerKey.length >= 4) {
      final stem = lowerKey.substring(0, lowerKey.length - 1);
      matchStart = lowerSentence.indexOf(stem);
      if (matchStart >= 0) {
        var end = matchStart + stem.length;
        while (end < sentence.length &&
            !RegExp(r'[\s.,;!?“”"()။၊]').hasMatch(sentence[end])) {
          end++;
        }
        matchLength = end - matchStart;
      }
    }

    if (matchStart < 0) {
      return Text(sentence, style: baseStyle);
    }

    return Text.rich(
      TextSpan(
        children: [
          if (matchStart > 0) TextSpan(text: sentence.substring(0, matchStart)),
          TextSpan(
            text: sentence.substring(matchStart, matchStart + matchLength),
            style: highlightStyle,
          ),
          if (matchStart + matchLength < sentence.length)
            TextSpan(text: sentence.substring(matchStart + matchLength)),
        ],
      ),
      style: baseStyle,
    );
  }

  Widget _buildVocabList(BuildContext context, bool isMm) {
    final list = widget.subCategory.vocabList ?? [];
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        final isActive = _activePlayIndex == index;
        final isHidden = _hideMeanings && !_revealedIndices.contains(index);
        final posTag = _extractPosTag(item.paliRoman, isMm);
        final primaryWord = isMm ? item.paliMm : item.paliRoman;
        final itemKey = _itemKeys.putIfAbsent(index, () => GlobalKey());

        return Card(
          key: itemKey,
          elevation: isActive ? 4 : 1.5,
          margin: const EdgeInsets.symmetric(vertical: 7),
          color: isActive
              ? colors.primaryContainer.withValues(alpha: 0.25)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: isActive
                ? BorderSide(color: colors.primary, width: 2)
                : BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.45),
                  ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _hideMeanings
                ? () {
                    setState(() {
                      if (_revealedIndices.contains(index)) {
                        _revealedIndices.remove(index);
                      } else {
                        _revealedIndices.add(index);
                      }
                    });
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top metadata row: POS/Gender tag + Active indicator + Actions
                  Row(
                    children: [
                      if (posTag != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.secondaryContainer.withValues(
                              alpha: 0.7,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            posTag,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colors.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                      if (isActive) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.graphic_eq_rounded,
                          size: 16,
                          color: colors.primary,
                        ),
                      ],
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: isMm ? 'မျှဝေရန်' : 'Share word',
                        icon: const Icon(Icons.share_outlined, size: 20),
                        onPressed: () {
                          showDialog<void>(
                            context: context,
                            builder: (dialogContext) => WordShareDialog(
                              word: item,
                              isMyanmar: isMm,
                              categoryTitle: isMm
                                  ? widget.subCategory.titleMm
                                  : widget.subCategory.titleEn,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
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
                        visualDensity: VisualDensity.compact,
                        tooltip: isMm ? 'အသံနားထောင်ရန်' : 'Listen',
                        icon: const Icon(Icons.volume_up_rounded),
                        onPressed: () {
                          _speakWithCheck(item.paliRoman, isMm);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    primaryWord,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isHidden)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.7,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            size: 16,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isMm
                                ? 'အဓိပ္ပာယ်ကြည့်ရန် နှိပ်ပါ'
                                : 'Tap card to reveal meaning',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      isMm ? item.translateMm : item.translateEn,
                      style: TextStyle(
                        fontSize: 16,
                        color: colors.onSurface,
                        height: 1.4,
                      ),
                    ),
                  if (item.example != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        border: Border(
                          left: BorderSide(
                            color: colors.primary,
                            width: 3.5,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHighlightedExampleText(
                                  sentence: isMm
                                      ? item.example!.paliMm
                                      : item.example!.paliRoman,
                                  rawKeyword: primaryWord,
                                  baseStyle: TextStyle(
                                    color: colors.primary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    height: 1.45,
                                  ),
                                  highlightStyle: TextStyle(
                                    color: colors.primary,
                                    fontWeight: FontWeight.bold,
                                    backgroundColor: colors.primaryContainer
                                        .withValues(alpha: 0.65),
                                  ),
                                ),
                                if (!isHidden) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    isMm
                                        ? item.example!.translateMm
                                        : item.example!.translateEn,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colors.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: isMm
                                ? 'စာကြောင်းအသံနားထောင်ရန်'
                                : 'Listen to sentence',
                            icon: const Icon(Icons.volume_up_rounded),
                            onPressed: () {
                              _speakWithCheck(item.example!.paliRoman, isMm);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogueList(BuildContext context, bool isMm) {
    final list = widget.subCategory.dialogueList ?? [];
    final colors = Theme.of(context).colorScheme;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final dialogue = list[index];
        final isActive = _activePlayIndex == index;
        final isHidden = _hideMeanings && !_revealedIndices.contains(index);
        final itemKey = _itemKeys.putIfAbsent(index, () => GlobalKey());

        return Card(
          key: itemKey,
          elevation: isActive ? 4 : 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          color: isActive
              ? colors.primaryContainer.withValues(alpha: 0.25)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isActive
                ? BorderSide(color: colors.primary, width: 2)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _hideMeanings
                ? () {
                    setState(() {
                      if (_revealedIndices.contains(index)) {
                        _revealedIndices.remove(index);
                      } else {
                        _revealedIndices.add(index);
                      }
                    });
                  }
                : null,
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
                        backgroundColor: colors.primaryContainer,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.mic_rounded,
                          color: Colors.deepOrange,
                        ),
                        onPressed: () {
                          _speakWithCheck(dialogue.paliRoman, isMm);
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
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!isHidden)
                    Text(
                      isMm ? dialogue.translateMm : dialogue.translateEn,
                      style: TextStyle(
                        fontSize: 15,
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  else
                    Text(
                      isMm
                          ? 'အဓိပ္ပာယ်ကြည့်ရန် နှိပ်ပါ'
                          : 'Tap card to reveal meaning',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
