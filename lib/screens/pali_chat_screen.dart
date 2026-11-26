import 'dart:async';

import 'package:flutter/material.dart';

import '../app_data.dart';
import '../pali_transliteration.dart';
import '../remote_app_config.dart';
import '../services/pali_chat_service.dart';
import '../services/tts_service.dart';

class PaliChatScreen extends StatefulWidget {
  final bool isMyanmar;
  final String initialRoomId;
  final bool embedded;

  const PaliChatScreen({
    super.key,
    required this.isMyanmar,
    this.initialRoomId = 'general',
    this.embedded = false,
  });

  @override
  State<PaliChatScreen> createState() => _PaliChatScreenState();
}

class _PaliChatScreenState extends State<PaliChatScreen> {
  late String _selectedRoomId;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _displayName;
  Set<String> _blockedUids = {};
  ChatMessage? _replyTo;
  bool _isCorrectionMode = false;
  bool _isSending = false;
  bool _showQuickPhrases = true;
  String? _authError;

  @override
  void initState() {
    super.initState();
    _selectedRoomId = widget.initialRoomId;
    unawaited(_initChatState());
  }

  Future<void> _initChatState() async {
    final name = await PaliChatService.getSavedDisplayName();
    final blocked = await PaliChatService.getBlockedUserIds();
    String? authErr;
    if (PaliChatService.isFirebaseReady) {
      try {
        await PaliChatService.ensureSignedIn();
      } catch (e) {
        authErr = e.toString();
      }
    }
    if (!mounted) return;
    setState(() {
      _displayName = name;
      _blockedUids = blocked;
      _authError = authErr;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  ChatRoomInfo get _currentRoom => kPaliChatRooms.firstWhere(
    (r) => r.id == _selectedRoomId,
    orElse: () => kPaliChatRooms.first,
  );

  void _insertTextAtCursor(String addition) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final updated = text.replaceRange(start, end, addition);
    _messageController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + addition.length),
    );
  }

  Future<String?> _promptDisplayName({bool force = false}) async {
    if (!force && _displayName != null && _displayName!.isNotEmpty) {
      return _displayName;
    }
    final isMm = widget.isMyanmar;
    final controller = TextEditingController(text: _displayName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isMm ? 'သင့်အမည် ထည့်သွင်းပါ' : 'Set your display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isMm ? 'ဥပမာ - မောင်မောင် / ဓမ္မသိင်္ဂီ' : 'e.g. Dhammapāla',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isMm ? 'ပယ်ဖျက်မည်' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(dialogContext, val);
              }
            },
            child: Text(isMm ? 'သိမ်းဆည်းမည်' : 'Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await PaliChatService.setSavedDisplayName(result);
      if (mounted) {
        setState(() => _displayName = result);
      }
    }
    return result;
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;
    final isMm = widget.isMyanmar;

    final name = await _promptDisplayName();
    if (name == null || name.isEmpty || !mounted) return;

    setState(() => _isSending = true);
    try {
      await PaliChatService.sendMessage(
        roomId: _selectedRoomId,
        text: text,
        senderNameOverride: name,
        replyTo: _replyTo,
        isCorrection: _isCorrectionMode,
      );
      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _replyTo = null;
        _isCorrectionMode = false;
        _authError = null;
      });
    } catch (error) {
      if (!mounted) return;
      final errStr = error.toString();
      setState(() => _authError = errStr);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errStr.contains('operation-not-allowed') ||
                    errStr.contains('admin-restricted-operation')
                ? (isMm
                      ? 'Firebase Console တွင် Anonymous Sign-in ကို ဖွင့်ပေးရန် လိုအပ်ပါသည်။'
                      : 'Please enable Anonymous Sign-in in Firebase Console.')
                : (isMm ? 'စာပို့၍ မရပါ: $error' : 'Failed to send message: $error'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  List<VocabItem> _lookupDictionaryMatches(String rawWord) {
    final clean = normalizePaliSearch(
      rawWord.replaceAll(RegExp(r'[.,;!?“”"()။၊]'), ''),
    );
    if (clean.length < 2) return const [];

    final matches = <VocabItem>[];
    final seen = <String>{};
    final categories = RemoteAppConfigRepository.current.apply(
      AppDataRepository.categories,
      includeHidden: true,
    );
    for (final cat in categories) {
      for (final sub in cat.subCategories) {
        for (final item in sub.vocabList ?? const <VocabItem>[]) {
          final normRoman = normalizePaliSearch(
            item.paliRoman.replaceAll(RegExp(r'\s*\([^)]*\)'), ''),
          );
          final normMm = normalizePaliSearch(
            item.paliMm.replaceAll(RegExp(r'\s*\([^)]*\)'), ''),
          );
          final stem = clean.length >= 4
              ? clean.substring(0, clean.length - 1)
              : clean;
          if (normRoman == clean ||
              normMm == clean ||
              normRoman.startsWith(stem) ||
              clean.startsWith(normRoman)) {
            if (seen.add(item.paliRoman)) {
              matches.add(item);
            }
          }
          if (matches.length >= 12) return matches;
        }
      }
    }
    return matches;
  }

  void _showWordLookupSheet(String messageText) {
    final isMm = widget.isMyanmar;
    final tokens = messageText
        .split(RegExp(r'\s+'))
        .where((t) => t.trim().isNotEmpty)
        .toList();
    String selectedToken = tokens.isNotEmpty ? tokens.first : '';
    List<VocabItem> matches = _lookupDictionaryMatches(selectedToken);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMm
                          ? 'ပါဠိစကားလုံး အဘိဓာန် ရှာဖွေရန်'
                          : 'Pāḷi Word Lookup',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isMm
                          ? 'အဓိပ္ပာယ်ကြည့်လိုသော စကားလုံးကို နှိပ်ပါ'
                          : 'Tap a word below to look up its meaning',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final token in tokens)
                          ChoiceChip(
                            label: Text(token),
                            selected: selectedToken == token,
                            onSelected: (_) {
                              setSheetState(() {
                                selectedToken = token;
                                matches = _lookupDictionaryMatches(token);
                              });
                            },
                          ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (matches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          isMm
                              ? '“$selectedToken” အတွက် သင်ခန်းစာဝေါဟာရထဲတွင် မတွေ့ပါ။'
                              : 'No lesson vocabulary match found for “$selectedToken”.',
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: matches.length,
                          itemBuilder: (context, index) {
                            final item = matches[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${item.paliMm} · ${item.paliRoman}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              subtitle: Text(
                                '${item.translateMm}\n${item.translateEn}',
                              ),
                              isThreeLine: true,
                              trailing: IconButton(
                                icon: const Icon(Icons.volume_up_rounded),
                                onPressed: () =>
                                    TtsService.speakPali(item.paliRoman),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmBlockUser(ChatMessage message) async {
    final isMm = widget.isMyanmar;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isMm ? 'အသုံးပြုသူကို ပိတ်ပင်မလား?' : 'Block user?'),
        content: Text(
          isMm
              ? '${message.senderName} ထံမှ စာများကို သင့်စာရင်းတွင် မမြင်ရတော့ပါ။'
              : 'You will no longer see messages from ${message.senderName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isMm ? 'မလုပ်ပါ' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isMm ? 'ပိတ်ပင်မည်' : 'Block'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await PaliChatService.blockUser(message.senderId);
      if (!mounted) return;
      setState(() {
        _blockedUids.add(message.senderId);
      });
    }
  }

  Future<void> _reportMessageDialog(ChatMessage message) async {
    final isMm = widget.isMyanmar;
    final reasons = isMm
        ? ['မသင့်လျော်သော စကားလုံး', 'Spam / ကြော်ငြာ', 'အနှောင့်အယှက်ပေးခြင်း']
        : ['Inappropriate content', 'Spam / Advertising', 'Harassment'];
    String selected = reasons.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isMm ? 'စာကို တိုင်ကြားရန်' : 'Report message'),
          content: RadioGroup<String>(
            groupValue: selected,
            onChanged: (value) {
              if (value != null) {
                setDialogState(() => selected = value);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final r in reasons)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(r),
                    value: r,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(isMm ? 'ပယ်ဖျက်မည်' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(isMm ? 'တိုင်ကြားမည်' : 'Report'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      await PaliChatService.reportMessage(
        roomId: _selectedRoomId,
        message: message,
        reason: selected,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMm
                ? 'တိုင်ကြားချက်ကို လက်ခံရရှိပါပြီ။'
                : 'Thank you. Your report has been submitted.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMm = widget.isMyanmar;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final room = _currentRoom;

    final body = Column(
      children: [
        if (widget.embedded)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _displayName != null
                      ? (isMm ? 'အမည်: $_displayName' : 'Name: $_displayName')
                      : (isMm ? 'အမည် မသတ်မှတ်ရသေးပါ' : 'No display name set'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _promptDisplayName(force: true),
                  icon: const Icon(Icons.badge_outlined, size: 16),
                  label: Text(isMm ? 'အမည်ပြောင်းရန်' : 'Set name'),
                ),
              ],
            ),
          ),
        // Room selector bar
          Container(
            color: colors.surfaceContainerLow,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final r in kPaliChatRooms)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: Icon(r.icon, size: 16),
                            label: Text(isMm ? r.titleMm : r.titleEn),
                            selected: _selectedRoomId == r.id,
                            onSelected: (_) {
                              setState(() {
                                _selectedRoomId = r.id;
                                _replyTo = null;
                                _isCorrectionMode = false;
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isMm ? room.descriptionMm : room.descriptionEn,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_authError != null)
            MaterialBanner(
              backgroundColor: colors.errorContainer,
              content: Text(
                _authError!.contains('operation-not-allowed') ||
                        _authError!.contains('admin-restricted-operation')
                    ? (isMm
                          ? 'အကောင့်ဝင်၍ မရပါ: Firebase Console → Authentication → Sign-in method တွင် Anonymous ကို Enable လုပ်ပေးပါ။'
                          : 'Sign-in blocked: Enable Anonymous Sign-In in Firebase Console → Authentication.')
                    : (isMm
                          ? 'ချိတ်ဆက်မှု အမှား: $_authError'
                          : 'Connection error: $_authError'),
                style: TextStyle(color: colors.onErrorContainer, fontSize: 12.5),
              ),
              actions: [
                TextButton(
                  onPressed: _initChatState,
                  child: Text(isMm ? 'ပြန်ကြိုးစားမည်' : 'Retry'),
                ),
              ],
            ),
          // Messages stream
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: PaliChatService.watchMessages(_selectedRoomId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        isMm
                            ? 'စကားပြောခန်း ချိတ်ဆက်၍ မရပါ။ အင်တာနက်ကို စစ်ဆေးပါ။'
                            : 'Unable to load messages. Please check your connection.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final messages = (snapshot.data ?? const <ChatMessage>[])
                    .where((m) => !_blockedUids.contains(m.senderId))
                    .toList();

                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            room.icon,
                            size: 48,
                            color: colors.primary.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isMm
                                ? 'ပါဠိဘာသာဖြင့် ပထမဆုံး စတင်နှုတ်ဆက်လိုက်ပါ!'
                                : 'Start the conversation in Pāḷi!',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isMm
                                ? 'အောက်ပါ အသင့်သုံး ပါဠိဝါကျများကို နှိပ်၍ စတင်နိုင်ပါသည်။'
                                : 'Tap any quick phrase below to say hello.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) =>
                      _buildMessageCard(context, messages[index], isMm),
                );
              },
            ),
          ),
          // Composer area
          _buildComposer(context, isMm),
        ],
      );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isMm ? 'ပါဠိစကားပြောခန်း' : 'Pāḷi Community Chat',
        ),
        actions: [
          IconButton(
            tooltip: isMm ? 'အမည်ပြောင်းရန်' : 'Set display name',
            icon: const Icon(Icons.badge_outlined),
            onPressed: () => _promptDisplayName(force: true),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildMessageCard(
    BuildContext context,
    ChatMessage message,
    bool isMm,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final myUid = PaliChatService.currentUid;
    final isMine = myUid != null && message.senderId == myUid;
    final timeStr =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:'
        '${message.createdAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 5),
          color: isMine
              ? colors.primaryContainer.withValues(alpha: 0.75)
              : colors.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Text(
                        message.senderName,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    Text(
                      timeStr,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (message.replyToText != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                          color: message.isCorrection
                              ? Colors.green.shade700
                              : colors.secondary,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.isCorrection
                              ? (isMm
                                    ? '✏️ ပြင်ဆင်အကြံပြုချက် (${message.replyToSender ?? ''})'
                                    : '✏️ Correction for ${message.replyToSender ?? ''}')
                              : (message.replyToSender ?? ''),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: message.isCorrection
                                ? Colors.green.shade800
                                : colors.secondary,
                          ),
                        ),
                        Text(
                          message.replyToText!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                SelectableText(
                  message.text,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: isMm ? 'အသံနားထောင်ရန်' : 'Listen',
                      icon: const Icon(Icons.volume_up_rounded, size: 18),
                      onPressed: () => TtsService.speakPali(message.text),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: isMm
                          ? 'စကားလုံး အဓိပ္ပာယ်ကြည့်ရန်'
                          : 'Lookup words',
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      onPressed: () => _showWordLookupSheet(message.text),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: isMm ? 'ပြန်ဖြေရန်' : 'Reply',
                      icon: const Icon(Icons.reply_rounded, size: 18),
                      onPressed: () {
                        setState(() {
                          _replyTo = message;
                          _isCorrectionMode = false;
                        });
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz_rounded, size: 18),
                      onSelected: (action) {
                        if (action == 'correct') {
                          setState(() {
                            _replyTo = message;
                            _isCorrectionMode = true;
                            _messageController.text = message.text;
                          });
                        } else if (action == 'report') {
                          _reportMessageDialog(message);
                        } else if (action == 'block') {
                          _confirmBlockUser(message);
                        } else if (action == 'delete') {
                          PaliChatService.deleteMessage(
                            roomId: _selectedRoomId,
                            messageId: message.id,
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'correct',
                          child: Text(
                            isMm
                                ? '✏️ ပြင်ဆင်အကြံပြုရန်'
                                : '✏️ Suggest correction',
                          ),
                        ),
                        if (!isMine) ...[
                          PopupMenuItem(
                            value: 'report',
                            child: Text(isMm ? '🚩 တိုင်ကြားရန်' : '🚩 Report'),
                          ),
                          PopupMenuItem(
                            value: 'block',
                            child: Text(
                              isMm ? '🚫 အသုံးပြုသူကို ပိတ်ပင်ရန်' : '🚫 Block user',
                            ),
                          ),
                        ] else
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(isMm ? '🗑️ ဖျက်ရန်' : '🗑️ Delete'),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(BuildContext context, bool isMm) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyTo != null)
              Container(
                color: colors.secondaryContainer.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Icon(
                      _isCorrectionMode
                          ? Icons.edit_note_rounded
                          : Icons.reply_rounded,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isCorrectionMode
                            ? (isMm
                                  ? 'ပြင်ဆင်အကြံပြုနေသည်: ${_replyTo!.text}'
                                  : 'Correcting: ${_replyTo!.text}')
                            : '${_replyTo!.senderName}: ${_replyTo!.text}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        setState(() {
                          _replyTo = null;
                          _isCorrectionMode = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            // Quick Pāḷi phrases bar
            if (_showQuickPhrases)
              SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  itemCount: kPaliQuickPhrases.length,
                  itemBuilder: (context, index) {
                    final phrase = kPaliQuickPhrases[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        visualDensity: VisualDensity.compact,
                        tooltip: isMm ? phrase.meaningMm : phrase.meaningEn,
                        label: Text(
                          phrase.pali,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _insertTextAtCursor(
                          _messageController.text.isEmpty
                              ? phrase.pali
                              : ' ${phrase.pali}',
                        ),
                      ),
                    );
                  },
                ),
              ),
            // Roman Pāḷi Quick Diacritic Toolbar
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: kPaliDiacritics.length,
                itemBuilder: (context, index) {
                  final ch = kPaliDiacritics[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _insertTextAtCursor(ch),
                      child: Container(
                        width: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ch,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: isMm ? 'အသင့်သုံး ဝါကျများ' : 'Quick phrases',
                    icon: Icon(
                      _showQuickPhrases
                          ? Icons.lightbulb_rounded
                          : Icons.lightbulb_outline_rounded,
                      color: _showQuickPhrases ? colors.primary : null,
                    ),
                    onPressed: () =>
                        setState(() => _showQuickPhrases = !_showQuickPhrases),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      decoration: InputDecoration(
                        hintText: isMm
                            ? 'ပါဠိဘာသာဖြင့် ရေးသားပါ...'
                            : 'Write a message in Pāḷi...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: isMm ? 'ပို့ရန်' : 'Send',
                    onPressed: _isSending ? null : _handleSend,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
