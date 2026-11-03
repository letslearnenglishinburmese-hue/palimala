import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:palimala/app_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _manifestUri = 'https://example.invalid/pali_data_manifest.json';
const _lessonUri = 'https://example.invalid/pali_data/new_words.json';
const _lessonJson =
    '{"id":"new_words","titleMm":"စကားလုံးအသစ်","titleEn":"New Words",'
    '"icon":"menu_book_rounded","subCategories":[]}';

String _manifest({String? hash, String id = 'new_words'}) => jsonEncode({
  'version': '2099-01-01T00:00:00.000Z',
  'datasets': [
    {
      'id': id,
      'titleMm': 'စကားလုံးအသစ်',
      'titleEn': 'New Words',
      'icon': 'menu_book_rounded',
      'asset': 'assets/pali_data/$id.json',
      'url': _lessonUri,
      'sha256': hash ?? List.filled(64, 'a').join(),
      'bytes': 1,
    },
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('keeps bundled lesson categories available when offline', () async {
    final categories = await AppDataRepository.loadBundled();

    expect(categories, isNotEmpty);
    expect(
      categories.map((category) => category.id),
      containsAll(['nouns', 'verbs', 'adjectives', 'adverbs', 'particles']),
    );
  });

  test('falls back to bundled manifest on invalid remote manifest', () async {
    await AppDataRepository.loadBundled();
    final invalidManifest = http.Response('{bad json', 200);

    await expectLater(
      AppDataRepository.checkForUpdates(
        client: MockClient((_) async => invalidManifest),
        manifestUri: Uri.parse(_manifestUri),
      ),
      throwsA(isA<DataUpdateException>()),
    );

    expect(AppDataRepository.categories, isNotEmpty);
  });

  test('falls back to bundled manifest after a network timeout', () async {
    await AppDataRepository.loadBundled();

    await expectLater(
      AppDataRepository.checkForUpdates(
        client: MockClient((_) => Completer<http.Response>().future),
        manifestUri: Uri.parse(_manifestUri),
        timeout: const Duration(milliseconds: 1),
      ),
      throwsA(isA<DataUpdateException>()),
    );

    expect(AppDataRepository.categories, isNotEmpty);
  });

  test(
    'rejects a downloaded lesson whose SHA-256 differs from manifest',
    () async {
      await AppDataRepository.loadBundled();
      await AppDataRepository.checkForUpdates(
        client: MockClient(
          (_) async => http.Response.bytes(utf8.encode(_manifest()), 200),
        ),
        manifestUri: Uri.parse(_manifestUri),
      );
      final dataset = AppDataRepository.datasets.single;

      await expectLater(
        AppDataRepository.downloadDataset(
          dataset,
          client: MockClient(
            (_) async => http.Response.bytes(utf8.encode(_lessonJson), 200),
          ),
        ),
        throwsA(
          isA<DataUpdateException>().having(
            (error) => error.message,
            'message',
            contains('SHA-256'),
          ),
        ),
      );
      expect(AppDataRepository.categories, isEmpty);
    },
  );

  test(
    'downloads a verified new lesson and restores it offline from cache',
    () async {
      final bytes = utf8.encode(_lessonJson);
      final digest = sha256.convert(bytes).toString();
      final manifest = _manifest(hash: digest);

      await AppDataRepository.loadBundled();
      final onlineClient = MockClient((request) async {
        if (request.url.path.endsWith('pali_data_manifest.json')) {
          return http.Response.bytes(utf8.encode(manifest), 200);
        }
        return http.Response.bytes(Uint8List.fromList(bytes), 200);
      });
      await AppDataRepository.checkForUpdates(
        client: onlineClient,
        manifestUri: Uri.parse(_manifestUri),
      );
      expect(AppDataRepository.datasets.single.id, 'new_words');
      expect(
        await AppDataRepository.downloadDataset(
          AppDataRepository.datasets.single,
          client: onlineClient,
        ),
        isTrue,
      );
      expect(AppDataRepository.categories.single.titleEn, 'New Words');

      final offlineClient = MockClient(
        (_) => throw http.ClientException('offline'),
      );
      await AppDataRepository.load(
        client: offlineClient,
        manifestUri: Uri.parse(_manifestUri),
        timeout: const Duration(milliseconds: 10),
      );
      await expectLater(
        AppDataRepository.checkForUpdates(
          client: offlineClient,
          manifestUri: Uri.parse(_manifestUri),
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<DataUpdateException>()),
      );

      expect(
        AppDataRepository.categories.any(
          (category) => category.id == 'new_words',
        ),
        isTrue,
      );
    },
  );
}
