import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimala/main.dart';
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

  group('PaliChatService Tests', () {
    test('saves and retrieves display name and blocked UIDs', () async {
      expect(await PaliChatService.getSavedDisplayName(), isNull);
      await PaliChatService.setSavedDisplayName('Dhammapāla');
      expect(await PaliChatService.getSavedDisplayName(), 'Dhammapāla');

      await PaliChatService.blockUser('bad_uid_1');
      await PaliChatService.blockUser('bad_uid_2');
      var blocked = await PaliChatService.getBlockedUserIds();
      expect(blocked, containsAll(['bad_uid_1', 'bad_uid_2']));

      await PaliChatService.unblockUser('bad_uid_1');
      blocked = await PaliChatService.getBlockedUserIds();
      expect(blocked, isNot(contains('bad_uid_1')));
      expect(blocked, contains('bad_uid_2'));
    });
  });

  group('PaliChatScreen Widget Tests', () {
    testWidgets('renders study rooms, quick phrases, and diacritic toolbar', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PaliChatScreen(isMyanmar: true),
        ),
      );
      await tester.pumpAndSettle();

      // Study rooms
      expect(find.text('ပါဠိစကားပြောခန်း'), findsWidgets);
      expect(find.text('သဒ္ဒါနှင့် ဝါကျအမေးအဖြေ'), findsOneWidget);
      expect(find.text('ဓမ္မစာပေ ဆွေးနွေးခန်း'), findsOneWidget);

      // Switch room
      await tester.tap(find.text('သဒ္ဒါနှင့် ဝါကျအမေးအဖြေ'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('ဝိဘတ်၊ အာချာတ်'),
        findsOneWidget,
      );

      // Tap quick phrase and diacritic key to insert into composer
      await tester.tap(find.text('Namo Buddhāya'));
      await tester.pump();
      await tester.tap(find.text('ā'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Namo Buddhāyaā');
    });

    testWidgets('sets display name via badge dialog', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PaliChatScreen(isMyanmar: true),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.badge_outlined));
      await tester.pumpAndSettle();

      expect(find.text('သင့်အမည် ထည့်သွင်းပါ'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Sīlānanda');
      await tester.tap(find.text('သိမ်းဆည်းမည်'));
      await tester.pumpAndSettle();

      expect(await PaliChatService.getSavedDisplayName(), 'Sīlānanda');
    });

    testWidgets('Bottom Navigation includes Chat tab and opens embedded chat', (
      tester,
    ) async {
      await tester.pumpWidget(const PaliLearningApp());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.forum_outlined));
      await tester.pumpAndSettle();

      expect(find.text('ပါဠိစကားပြောခန်း'), findsWidgets);
      expect(find.text('Namo Buddhāya'), findsOneWidget);
    });
  });
}
