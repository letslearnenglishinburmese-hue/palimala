import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:palimala/app_data.dart';
import 'package:palimala/remote_app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object?> _config({
  String color = '#8C1D11',
  int columns = 2,
  bool showStatistics = true,
  bool showExploreHeading = true,
}) => {
  'schemaVersion': 1,
  'categories': [
    {
      'id': 'verbs',
      'titleMm': 'ကြိယာ',
      'titleEn': 'Verbs',
      'icon': 'directions_run_rounded',
      'visible': true,
      'order': 2,
    },
    {
      'id': 'nouns',
      'titleMm': 'နာမ်',
      'titleEn': 'Nouns',
      'icon': 'menu_book_rounded',
      'visible': false,
      'order': 1,
    },
  ],
  'theme': {
    'light': {
      'primary': color,
      'secondary': '#D97706',
      'surface': '#FDFBF7',
      'background': '#F7F3ED',
    },
    'dark': {
      'primary': '#E7A08A',
      'secondary': '#F3B95F',
      'surface': '#302925',
      'background': '#211C19',
    },
  },
  'home': {
    'showDailyWord': false,
    'showStatistics': showStatistics,
    'showExploreHeading': showExploreHeading,
    'columns': columns,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses valid category, theme, and home settings', () {
    final config = RemoteAppConfig.parse(jsonEncode(_config()));
    expect(config.categories, hasLength(2));
    expect(config.home.showDailyWord, isFalse);
    expect(config.home.showStatistics, isTrue);
    expect(config.home.showExploreHeading, isTrue);
    expect(config.home.columns, 2);
    expect(config.lightColors['primary']!.toARGB32(), 0xFF8C1D11);
    expect(config.darkColors['primary']!.toARGB32(), 0xFFE7A08A);
  });

  test('builds light and dark themes from remote colors', () {
    final config = RemoteAppConfig.parse(jsonEncode(_config()));
    final light = buildRemoteTheme(config, dark: false);
    final dark = buildRemoteTheme(config, dark: true);

    expect(light.colorScheme.brightness, Brightness.light);
    expect(light.colorScheme.primary.toARGB32(), 0xFF8C1D11);
    expect(light.scaffoldBackgroundColor.toARGB32(), 0xFFF7F3ED);
    expect(dark.colorScheme.brightness, Brightness.dark);
    expect(dark.colorScheme.primary.toARGB32(), 0xFFE7A08A);
    expect(dark.scaffoldBackgroundColor.toARGB32(), 0xFF211C19);
  });

  test('accepts supported home layout choices and rejects invalid columns', () {
    final config = RemoteAppConfig.parse(
      jsonEncode(
        _config(columns: 3, showStatistics: false, showExploreHeading: false),
      ),
    );
    expect(config.home.columns, 3);
    expect(config.home.showStatistics, isFalse);
    expect(config.home.showExploreHeading, isFalse);
    expect(
      () => RemoteAppConfig.parse(jsonEncode(_config(columns: 4))),
      throwsFormatException,
    );
  });

  test('rejects unsupported icons and malformed colors', () {
    final unknownIcon = _config();
    (unknownIcon['categories'] as List)[0]['icon'] = 'launch_intent';
    expect(
      () => RemoteAppConfig.parse(jsonEncode(unknownIcon)),
      throwsFormatException,
    );
    expect(
      () => RemoteAppConfig.parse(jsonEncode(_config(color: 'red'))),
      throwsFormatException,
    );
  });

  test('orders visible categories and removes hidden categories', () {
    final config = RemoteAppConfig.parse(jsonEncode(_config()));
    final result = config.apply([
      MainCategory(
        id: 'nouns',
        titleMm: 'old N',
        titleEn: 'Old N',
        icon: const IconData(0),
        subCategories: const [],
      ),
      MainCategory(
        id: 'verbs',
        titleMm: 'old V',
        titleEn: 'Old V',
        icon: const IconData(0),
        subCategories: const [],
      ),
    ]);
    expect(result, hasLength(1));
    expect(result.single.id, 'verbs');
    expect(result.single.titleEn, 'Verbs');
    expect(result.single.titleMm, 'ကြိယာ');
    expect(result.single.icon, Icons.directions_run_rounded);

    final includingHidden = config.apply([
      MainCategory(
        id: 'nouns',
        titleMm: 'old N',
        titleEn: 'Old N',
        icon: const IconData(0),
        subCategories: const [],
      ),
      MainCategory(
        id: 'verbs',
        titleMm: 'old V',
        titleEn: 'Old V',
        icon: const IconData(0),
        subCategories: const [],
      ),
    ], includeHidden: true);
    expect(includingHidden.map((category) => category.id), ['nouns', 'verbs']);
    expect(includingHidden.first.titleMm, 'နာမ်');
  });

  test('adds a visible remote-only category with no lessons', () async {
    final source = _config();
    (source['categories'] as List).add({
      'id': 'conversation_patterns',
      'titleMm': 'ပါဠိစကားပြောပုံစံများ',
      'titleEn': 'Pali Conversation Patterns',
      'icon': 'school_rounded',
      'visible': true,
      'order': 3,
    });
    SharedPreferences.setMockInitialValues({});
    final client = MockClient(
      (_) async => http.Response.bytes(utf8.encode(jsonEncode(source)), 200),
    );
    addTearDown(client.close);
    await RemoteAppConfigRepository.refresh(
      client: client,
      remoteUri: Uri.https('example.invalid', '/app_config.json'),
    );
    final config = RemoteAppConfigRepository.current;
    final result = config.apply([
      MainCategory(
        id: 'verbs',
        titleMm: 'ကြိယာ',
        titleEn: 'Verbs',
        icon: Icons.directions_run_rounded,
        subCategories: const [],
      ),
    ]);

    final added = result.singleWhere(
      (category) => category.id == 'conversation_patterns',
    );
    expect(added.titleMm, 'ပါဠိစကားပြောပုံစံများ');
    expect(added.titleEn, 'Pali Conversation Patterns');
    expect(added.icon, Icons.school_rounded);
    expect(added.subCategories, isEmpty);
    expect(result.map((category) => category.id), [
      'verbs',
      'conversation_patterns',
    ]);
  });

  test('rejects duplicate category IDs and unknown fields', () {
    final duplicate = _config();
    (duplicate['categories'] as List)[1]['id'] = 'verbs';
    expect(
      () => RemoteAppConfig.parse(jsonEncode(duplicate)),
      throwsFormatException,
    );
    final unknownField = _config()..['surprise'] = true;
    expect(
      () => RemoteAppConfig.parse(jsonEncode(unknownField)),
      throwsFormatException,
    );
  });

  test(
    'uses the last valid cached config when the network is unavailable',
    () async {
      final cached = jsonEncode(_config());
      SharedPreferences.setMockInitialValues({
        'pali_remote_app_config_v1': cached,
      });
      await RemoteAppConfigRepository.load(
        client: MockClient((_) async => throw Exception('offline')),
        remoteUri: Uri.https('example.invalid', '/app_config.json'),
      );
      expect(RemoteAppConfigRepository.current.categories.first.id, 'verbs');
      expect(RemoteAppConfigRepository.current.home.showDailyWord, isFalse);
    },
  );

  test('discards malformed cache and uses bundled defaults', () async {
    SharedPreferences.setMockInitialValues({
      'pali_remote_app_config_v1': '{broken json',
    });
    await RemoteAppConfigRepository.load(
      client: MockClient((_) async => throw Exception('offline')),
      remoteUri: Uri.https('example.invalid', '/app_config.json'),
    );
    expect(RemoteAppConfigRepository.current.categories, hasLength(8));
    expect(RemoteAppConfigRepository.current.home.showDailyWord, isTrue);
  });

  test('accepts and caches a valid HTTPS remote config', () async {
    SharedPreferences.setMockInitialValues({});
    final source = jsonEncode(_config());
    await RemoteAppConfigRepository.refresh(
      client: MockClient((request) async {
        expect(request.url.scheme, 'https');
        return http.Response.bytes(utf8.encode(source), 200);
      }),
      remoteUri: Uri.https('example.invalid', '/app_config.json'),
    );
    final preferences = await SharedPreferences.getInstance();
    expect(RemoteAppConfigRepository.current.categories.first.id, 'verbs');
    expect(preferences.getString('pali_remote_app_config_v1'), source);
  });

  test('keeps the cached config when the server returns an error', () async {
    final cached = jsonEncode(_config());
    SharedPreferences.setMockInitialValues({
      'pali_remote_app_config_v1': cached,
    });
    final pendingRemote = Completer<http.Response>();
    await RemoteAppConfigRepository.load(
      client: MockClient((_) => pendingRemote.future),
      remoteUri: Uri.https('example.invalid', '/app_config.json'),
    );

    await RemoteAppConfigRepository.refresh(
      client: MockClient((_) async => http.Response('', 503)),
      remoteUri: Uri.https('example.invalid', '/app_config.json'),
    );

    final preferences = await SharedPreferences.getInstance();
    expect(RemoteAppConfigRepository.current.categories.first.id, 'verbs');
    expect(preferences.getString('pali_remote_app_config_v1'), cached);
    pendingRemote.complete(http.Response('', 503));
  });

  test(
    'rejects invalid remote JSON without replacing the cached config',
    () async {
      final cached = jsonEncode(_config());
      SharedPreferences.setMockInitialValues({
        'pali_remote_app_config_v1': cached,
      });
      final pendingRemote = Completer<http.Response>();
      await RemoteAppConfigRepository.load(
        client: MockClient((_) => pendingRemote.future),
        remoteUri: Uri.https('example.invalid', '/app_config.json'),
      );

      await RemoteAppConfigRepository.refresh(
        client: MockClient(
          (_) async =>
              http.Response.bytes(utf8.encode('{"schemaVersion":1}'), 200),
        ),
        remoteUri: Uri.https('example.invalid', '/app_config.json'),
      );

      final preferences = await SharedPreferences.getInstance();
      expect(RemoteAppConfigRepository.current.categories.first.id, 'verbs');
      expect(preferences.getString('pali_remote_app_config_v1'), cached);
      pendingRemote.complete(http.Response('', 503));
    },
  );

  test(
    'rejects a structurally invalid remote config without replacing cache',
    () async {
      final cached = jsonEncode(_config());
      SharedPreferences.setMockInitialValues({
        'pali_remote_app_config_v1': cached,
      });
      final invalid = _config();
      (invalid['categories'] as List)[0]['icon'] = 'unapproved_icon';
      await RemoteAppConfigRepository.refresh(
        client: MockClient(
          (_) async =>
              http.Response.bytes(utf8.encode(jsonEncode(invalid)), 200),
        ),
        remoteUri: Uri.https('example.invalid', '/app_config.json'),
      );

      final preferences = await SharedPreferences.getInstance();
      expect(RemoteAppConfigRepository.current.categories.first.id, 'verbs');
      expect(preferences.getString('pali_remote_app_config_v1'), cached);
    },
  );

  test(
    'times out remote config refresh and keeps last valid snapshot',
    () async {
      final cached = jsonEncode(_config());
      SharedPreferences.setMockInitialValues({
        'pali_remote_app_config_v1': cached,
      });
      final pendingRemote = Completer<http.Response>();
      await RemoteAppConfigRepository.load(
        client: MockClient((_) => pendingRemote.future),
        remoteUri: Uri.https('example.invalid', '/app_config.json'),
        timeout: const Duration(milliseconds: 1),
      );
      await RemoteAppConfigRepository.refresh(
        client: MockClient((_) => pendingRemote.future),
        remoteUri: Uri.https('example.invalid', '/app_config.json'),
        timeout: const Duration(milliseconds: 1),
      );

      expect(RemoteAppConfigRepository.current.categories.first.id, 'verbs');
      pendingRemote.complete(http.Response('', 503));
    },
  );
}
