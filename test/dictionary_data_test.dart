import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palimala/dictionary_data.dart';
import 'package:palimala/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final selectedTab = ValueNotifier<int>(4);

  test('parses dictionary entries and converts definition HTML to text', () {
    final entries = DictionaryRepository.parseJson(
      '[{"word":"cakāra","definition":"<p>စက္က<br>ဘီး &amp; စက်</p>"}]',
    );

    expect(entries, hasLength(1));
    expect(entries.single.word, 'cakāra');
    expect(entries.single.normalizedWord, 'cakāra');
    expect(entries.single.definition, 'စက္က\nဘီး & စက်');
  });

  test('rejects dictionary entries with missing fields', () {
    expect(
      () => DictionaryRepository.parseJson('[{"word":"ca"}]'),
      throwsFormatException,
    );
  });

  test('loads Pāḷi entries from the bundled Myanmar dictionary', () async {
    final entries = await DictionaryRepository.loadBundled();
    final cakara = entries.firstWhere(
      (entry) => entry.normalizedWord == 'cakāra',
    );

    expect(cakara.definition, contains('စကာရ'));
  });

  testWidgets('searches the bundled dictionary from its tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          currentLang: AppLanguage.english,
          onLanguageToggle: () {},
          selectedTab: selectedTab,
          savedWords: const {},
          onSavedWordToggle: (_) {},
          textScale: 1,
          onTextScaleChanged: (_) {},
          isDarkMode: false,
          onThemeChanged: (_) {},
        ),
      ),
    );
    await tester.runAsync(() => DictionaryRepository.loadBundled());
    await tester.pump();
    await tester.pump();

    expect(find.text('Dictionary'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'cakāra');
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('cakāra'), findsWidgets);
    expect(find.textContaining('စကာရ'), findsWidgets);
  });
}
