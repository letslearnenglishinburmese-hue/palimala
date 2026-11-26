import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

class ChatRoomInfo {
  final String id;
  final String titleMm;
  final String titleEn;
  final String descriptionMm;
  final String descriptionEn;
  final IconData icon;

  const ChatRoomInfo({
    required this.id,
    required this.titleMm,
    required this.titleEn,
    required this.descriptionMm,
    required this.descriptionEn,
    required this.icon,
  });
}

class PaliQuickPhrase {
  final String pali;
  final String meaningMm;
  final String meaningEn;

  const PaliQuickPhrase({
    required this.pali,
    required this.meaningMm,
    required this.meaningEn,
  });
}

const List<ChatRoomInfo> kPaliChatRooms = [
  ChatRoomInfo(
    id: 'general',
    titleMm: 'ပါဠိစကားပြောခန်း',
    titleEn: 'Pāḷi Lounge',
    descriptionMm: 'နေ့စဉ်သုံး ပါဠိဝါကျတိုများဖြင့် အပြန်အလှန် နှုတ်ဆက်စကားပြောရန်',
    descriptionEn: 'Practice everyday Pāḷi greetings and short conversations',
    icon: Icons.forum_rounded,
  ),
  ChatRoomInfo(
    id: 'grammar',
    titleMm: 'သဒ္ဒါနှင့် ဝါကျအမေးအဖြေ',
    titleEn: 'Grammar Q&A',
    descriptionMm: 'ဝိဘတ်၊ အာချာတ်နှင့် ပါဠိဝါကျတည်ဆောက်ပုံများ မေးမြန်းဆွေးနွေးရန်',
    descriptionEn: 'Ask questions about declensions, verbs, and sentence structure',
    icon: Icons.school_rounded,
  ),
  ChatRoomInfo(
    id: 'dhamma',
    titleMm: 'ဓမ္မစာပေ ဆွေးနွေးခန်း',
    titleEn: 'Dhamma Study',
    descriptionMm: 'ပိဋကတ်စာပေနှင့် ဂါထာတော်များမှ ပါဠိအနက်အဓိပ္ပာယ် ဆွေးနွေးရန်',
    descriptionEn: 'Discuss Tipiṭaka verses and Dhamma vocabulary together',
    icon: Icons.menu_book_rounded,
  ),
];

const List<String> kPaliDiacritics = [
  'ā',
  'ī',
  'ū',
  'ṃ',
  'ṅ',
  'ñ',
  'ṭ',
  'ḍ',
  'ṇ',
  'ḷ',
];

const List<PaliQuickPhrase> kPaliQuickPhrases = [
  PaliQuickPhrase(
    pali: 'Namo Buddhāya',
    meaningMm: 'မြတ်စွာဘုရားအား ရှိခိုးပါ၏',
    meaningEn: 'Homage to the Buddha',
  ),
  PaliQuickPhrase(
    pali: 'Suvatthi hotu!',
    meaningMm: 'ချမ်းသာခြင်း ဖြစ်ပါစေ',
    meaningEn: 'May there be well-being!',
  ),
  PaliQuickPhrase(
    pali: 'Kacci nu kho te khamanīyaṃ?',
    meaningMm: 'နေကောင်းပါရဲ့လား',
    meaningEn: 'How are you / Is it bearable?',
  ),
  PaliQuickPhrase(
    pali: 'Āma, sukhaṃ.',
    meaningMm: 'ဟုတ်ကဲ့၊ ချမ်းသာပါ၏',
    meaningEn: 'Yes, I am well.',
  ),
  PaliQuickPhrase(
    pali: 'Sādhu! Sādhu!',
    meaningMm: 'သာဓု! သာဓု!',
    meaningEn: 'Well said! Excellent!',
  ),
  PaliQuickPhrase(
    pali: 'Anumodāmi.',
    meaningMm: 'ဝမ်းမြောက်ဝမ်းသာ သာဓုခေါ်ပါ၏',
    meaningEn: 'I rejoice in your merit.',
  ),
];

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;
  final String? replyToId;
  final String? replyToSender;
  final String? replyToText;
  final bool isCorrection;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.replyToId,
    this.replyToSender,
    this.replyToText,
    this.isCorrection = false,
  });

  factory ChatMessage.fromFirestore(
    String roomId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['createdAt'];
    final date = ts is Timestamp ? ts.toDate() : DateTime.now();
    return ChatMessage(
      id: doc.id,
      roomId: roomId,
      senderId: (data['senderId'] as String?) ?? '',
      senderName: (data['senderName'] as String?) ?? 'Pāḷi Learner',
      text: (data['text'] as String?) ?? '',
      createdAt: date,
      replyToId: data['replyToId'] as String?,
      replyToSender: data['replyToSender'] as String?,
      replyToText: data['replyToText'] as String?,
      isCorrection: (data['isCorrection'] as bool?) ?? false,
    );
  }
}

class PaliChatService {
  static const _displayNameKey = 'pali_chat_display_name';
  static const _blockedUidsKey = 'pali_chat_blocked_uids';

  static bool get isFirebaseReady => Firebase.apps.isNotEmpty;

  static Future<bool> ensureFirebaseInitialized() async {
    if (Firebase.apps.isNotEmpty) return true;
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return Firebase.apps.isNotEmpty;
  }

  static String? get currentUid {
    if (!isFirebaseReady) return null;
    return FirebaseAuth.instance.currentUser?.uid;
  }

  static Future<String?> getSavedDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_displayNameKey)?.trim();
    return (name == null || name.isEmpty) ? null : name;
  }

  static Future<void> setSavedDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayNameKey, trimmed);
    if (isFirebaseReady) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await user.updateDisplayName(trimmed);
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
            {
              'displayName': trimmed,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        } catch (_) {}
      }
    }
  }

  static Future<User?> ensureSignedIn({String? preferredName}) async {
    await ensureFirebaseInitialized();
    final auth = FirebaseAuth.instance;
    var user = auth.currentUser;
    if (user == null) {
      final cred = await auth.signInAnonymously();
      user = cred.user;
    }
    if (preferredName != null && preferredName.trim().isNotEmpty) {
      await setSavedDisplayName(preferredName);
    }
    return user;
  }

  static Stream<List<ChatMessage>> watchMessages(String roomId) {
    if (!isFirebaseReady) {
      return Stream.value(const <ChatMessage>[]);
    }
    return FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limitToLast(100)
        .snapshots()
        .map(
          (snap) => [
            for (final doc in snap.docs) ChatMessage.fromFirestore(roomId, doc),
          ],
        );
  }

  static Future<void> sendMessage({
    required String roomId,
    required String text,
    String? senderNameOverride,
    ChatMessage? replyTo,
    bool isCorrection = false,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final user = await ensureSignedIn(preferredName: senderNameOverride);
    if (user == null) {
      throw StateError('Unable to authenticate user.');
    }
    final savedName = await getSavedDisplayName();
    final senderName =
        senderNameOverride?.trim().isNotEmpty == true
            ? senderNameOverride!.trim()
            : (savedName ?? user.displayName ?? 'Pāḷi Learner');

    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .add({
          'senderId': user.uid,
          'senderName': senderName,
          'text': trimmed,
          'createdAt': FieldValue.serverTimestamp(),
          if (replyTo != null) 'replyToId': replyTo.id,
          if (replyTo != null) 'replyToSender': replyTo.senderName,
          if (replyTo != null) 'replyToText': replyTo.text,
          'isCorrection': isCorrection,
        });
  }

  static Future<void> deleteMessage({
    required String roomId,
    required String messageId,
  }) async {
    if (!isFirebaseReady) return;
    await FirebaseFirestore.instance
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  static Future<Set<String>> getBlockedUserIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_blockedUidsKey) ?? const []).toSet();
  }

  static Future<void> blockUser(String uid) async {
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_blockedUidsKey) ?? const []).toSet();
    current.add(uid);
    await prefs.setStringList(_blockedUidsKey, current.toList());
  }

  static Future<void> unblockUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final current = (prefs.getStringList(_blockedUidsKey) ?? const []).toSet();
    current.remove(uid);
    await prefs.setStringList(_blockedUidsKey, current.toList());
  }

  static Future<void> reportMessage({
    required String roomId,
    required ChatMessage message,
    required String reason,
  }) async {
    if (!isFirebaseReady) return;
    final user = await ensureSignedIn();
    await FirebaseFirestore.instance.collection('chat_reports').add({
      'roomId': roomId,
      'messageId': message.id,
      'reportedUid': message.senderId,
      'messageText': message.text,
      'reason': reason,
      'reporterUid': user?.uid ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
