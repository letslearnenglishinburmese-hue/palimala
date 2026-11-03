import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:palimala/app_data.dart';
import 'package:palimala/remote_app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _runLiveRemoteIntegration = bool.fromEnvironment(
  'LIVE_REMOTE_INTEGRATION',
);

class _CurlClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final result = await Process.run('curl', [
      '--silent',
      '--show-error',
      '--location',
      '--max-time',
      '20',
      '--write-out',
      '\n%{http_code}',
      request.url.toString(),
    ]);
    if (result.exitCode != 0) {
      throw http.ClientException(
        'Live request failed: ${result.stderr}',
        request.url,
      );
    }
    final output = result.stdout as String;
    final statusStart = output.lastIndexOf('\n');
    final body = output.substring(0, statusStart);
    final status = int.parse(output.substring(statusStart + 1));
    final bytes = utf8.encode(body);
    return http.StreamedResponse(
      Stream.value(bytes),
      status,
      contentLength: bytes.length,
      request: request,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fetches, verifies, caches, and opens the published Furniture lesson offline', () async {
    SharedPreferences.setMockInitialValues({});
    final client = _CurlClient();
    addTearDown(client.close);

    await AppDataRepository.loadBundled();
    await AppDataRepository.checkForUpdates(client: client);
    final nouns = AppDataRepository.datasets.firstWhere(
      (dataset) => dataset.id == 'nouns',
    );
    final liveDataset = await client.get(Uri.parse(nouns.url));
    expect(liveDataset.statusCode, 200);
    expect(sha256.convert(liveDataset.bodyBytes).toString(), nouns.sha256);
    final alreadyCurrent =
        AppDataRepository.statusOf(nouns) == DatasetStatus.upToDate;
    expect(
      await AppDataRepository.downloadDataset(nouns, client: client),
      !alreadyCurrent,
    );
    expect(AppDataRepository.hasDownloadedCopy(nouns), !alreadyCurrent);

    final cachedNouns = AppDataRepository.categories.firstWhere(
      (category) => category.id == 'nouns',
    );
    expect(
      cachedNouns.subCategories
          .firstWhere((lesson) => lesson.titleEn == 'Furniture')
          .vocabList,
      hasLength(20),
    );

    final offline = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    addTearDown(offline.close);
    await AppDataRepository.load(client: offline);

    final offlineNouns = AppDataRepository.categories.firstWhere(
      (category) => category.id == 'nouns',
    );
    expect(AppDataRepository.hasDownloadedCopy(nouns), !alreadyCurrent);
    expect(
      offlineNouns.subCategories
          .firstWhere((lesson) => lesson.titleEn == 'Furniture')
          .vocabList,
      hasLength(20),
    );
  }, skip: !_runLiveRemoteIntegration);

  test(
    'fetches and validates the published remote app configuration',
    () async {
      SharedPreferences.setMockInitialValues({});
      final client = _CurlClient();
      addTearDown(client.close);

      await RemoteAppConfigRepository.refresh(client: client);
      expect(RemoteAppConfigRepository.current.categories, isNotEmpty);
      expect(
        RemoteAppConfigRepository.current.categories.map(
          (category) => category.id,
        ),
        contains('nouns'),
      );

      final offline = MockClient(
        (_) async => throw http.ClientException('offline'),
      );
      addTearDown(offline.close);
      await RemoteAppConfigRepository.load(client: offline);
      expect(
        RemoteAppConfigRepository.current.categories.map(
          (category) => category.id,
        ),
        contains('nouns'),
      );
    },
    skip: !_runLiveRemoteIntegration,
  );
}
