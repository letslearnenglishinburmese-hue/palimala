import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_data.dart';

const _configAsset = 'assets/app_config.json';
const _configUrl =
    'https://raw.githubusercontent.com/letslearnenglishinburmese-hue/palimala/main/assets/app_config.json';
const _cacheKey = 'pali_remote_app_config_v1';
const _configTimeout = Duration(seconds: 5);

/// A validated configuration snapshot. URLs and lesson hashes stay in the
/// existing manifest and are deliberately not duplicated here.
@immutable
class RemoteAppConfig {
  final List<RemoteCategoryConfig> categories;
  final Map<String, Color> lightColors;
  final Map<String, Color> darkColors;
  final HomeOptions home;

  const RemoteAppConfig({
    required this.categories,
    required this.lightColors,
    required this.darkColors,
    required this.home,
  });

  static RemoteAppConfig parse(String source) {
    final root = _map(jsonDecode(source), 'config');
    _keys(root, {'schemaVersion', 'categories', 'theme', 'home'}, 'config');
    if (root['schemaVersion'] != 1) {
      throw const FormatException('Unsupported config schemaVersion.');
    }
    final categoryValues = root['categories'];
    if (categoryValues is! List ||
        categoryValues.isEmpty ||
        categoryValues.length > 100) {
      throw const FormatException('categories must contain 1 to 100 entries.');
    }
    final categories = categoryValues
        .map((value) => RemoteCategoryConfig.parse(_map(value, 'category')))
        .toList();
    final ids = categories.map((category) => category.id).toSet();
    final orders = categories.map((category) => category.order).toSet();
    if (ids.length != categories.length || orders.length != categories.length) {
      throw const FormatException('Category IDs and orders must be unique.');
    }
    final theme = _map(root['theme'], 'theme');
    _keys(theme, {'light', 'dark'}, 'theme');
    final home = HomeOptions.parse(_map(root['home'], 'home'));
    return RemoteAppConfig(
      categories: categories,
      lightColors: _colors(_map(theme['light'], 'theme.light')),
      darkColors: _colors(_map(theme['dark'], 'theme.dark')),
      home: home,
    );
  }

  List<MainCategory> apply(
    List<MainCategory> source, {
    bool includeHidden = false,
  }) {
    final byId = {for (final category in source) category.id: category};
    final ordered = [...categories]..sort((a, b) => a.order.compareTo(b.order));
    return [
      for (final setting in ordered)
        if (setting.visible || includeHidden)
          if (byId[setting.id] case final category?)
            category.copyWith(
              titleMm: setting.titleMm,
              titleEn: setting.titleEn,
              icon: _icons[setting.icon]!,
            )
          else
            MainCategory(
              id: setting.id,
              titleMm: setting.titleMm,
              titleEn: setting.titleEn,
              icon: _icons[setting.icon]!,
              subCategories: const [],
            ),
      // Keep datasets introduced by a newer lesson manifest readable. They
      // appear after configured categories with their manifest metadata.
      for (final category in source)
        if (!ids.contains(category.id)) category,
    ];
  }

  Set<String> get ids => categories.map((category) => category.id).toSet();

  static Map<String, Color> _colors(Map<String, dynamic> value) {
    const names = {'primary', 'secondary', 'surface', 'background'};
    _keys(value, names, 'theme colors');
    if (value.keys.toSet().difference(names).isNotEmpty ||
        names.difference(value.keys.toSet()).isNotEmpty) {
      throw const FormatException('Theme must define all supported colors.');
    }
    return {
      for (final entry in value.entries)
        entry.key: _color(entry.value, 'theme.${entry.key}'),
    };
  }
}

/// Builds the app's Material theme from one validated remote snapshot.
ThemeData buildRemoteTheme(RemoteAppConfig config, {required bool dark}) {
  final colors = dark ? config.darkColors : config.lightColors;
  final brightness = dark ? Brightness.dark : Brightness.light;
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: colors['background'],
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors['primary']!,
      brightness: brightness,
      primary: colors['primary']!,
      secondary: colors['secondary']!,
      surface: colors['surface']!,
    ),
    fontFamily: 'Pyidaungsu Numbers',
    fontFamilyFallback: const ['Pyidaungsu', 'GentiumPlus', 'SourceSans3'],
  );
}

@immutable
class RemoteCategoryConfig {
  final String id;
  final String titleMm;
  final String titleEn;
  final String icon;
  final bool visible;
  final int order;

  const RemoteCategoryConfig({
    required this.id,
    required this.titleMm,
    required this.titleEn,
    required this.icon,
    required this.visible,
    required this.order,
  });

  factory RemoteCategoryConfig.parse(Map<String, dynamic> value) {
    _keys(value, {
      'id',
      'titleMm',
      'titleEn',
      'icon',
      'visible',
      'order',
    }, 'category');
    final id = _text(value['id'], 'category.id', 64);
    if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(id)) {
      throw const FormatException('category.id has invalid characters.');
    }
    final icon = _text(value['icon'], 'category.icon', 64);
    if (!_icons.containsKey(icon)) {
      throw FormatException('Unsupported icon "$icon".');
    }
    final visible = value['visible'];
    final order = value['order'];
    if (visible is! bool || order is! int || order < 0 || order > 10000) {
      throw const FormatException('Category visible/order value is invalid.');
    }
    return RemoteCategoryConfig(
      id: id,
      titleMm: _text(value['titleMm'], 'category.titleMm', 120),
      titleEn: _text(value['titleEn'], 'category.titleEn', 120),
      icon: icon,
      visible: visible,
      order: order,
    );
  }
}

@immutable
class HomeOptions {
  final bool showDailyWord;
  final bool showStatistics;
  final bool showExploreHeading;
  final int columns;

  const HomeOptions({
    required this.showDailyWord,
    required this.showStatistics,
    required this.showExploreHeading,
    required this.columns,
  });

  factory HomeOptions.parse(Map<String, dynamic> value) {
    const names = {
      'showDailyWord',
      'showStatistics',
      'showExploreHeading',
      'columns',
    };
    _keys(value, names, 'home');
    if (value.keys.toSet().difference(names).isNotEmpty ||
        names.difference(value.keys.toSet()).isNotEmpty) {
      throw const FormatException(
        'home contains missing or unsupported options.',
      );
    }
    final daily = value['showDailyWord'];
    final stats = value['showStatistics'];
    final heading = value['showExploreHeading'];
    final columns = value['columns'];
    if (daily is! bool ||
        stats is! bool ||
        heading is! bool ||
        columns is! int ||
        (columns != 2 && columns != 3)) {
      throw const FormatException('home option value is invalid.');
    }
    return HomeOptions(
      showDailyWord: daily,
      showStatistics: stats,
      showExploreHeading: heading,
      columns: columns,
    );
  }
}

/// Loads a bundled default immediately, then promotes only valid cached/HTTPS
/// snapshots. Invalid remote data never replaces a known-good configuration.
final class RemoteAppConfigRepository {
  RemoteAppConfigRepository._();
  static RemoteAppConfig _current = const RemoteAppConfig(
    categories: [],
    lightColors: {
      'primary': Color(0xFF8C1D11),
      'secondary': Color(0xFFD97706),
      'surface': Color(0xFFFDFBF7),
      'background': Color(0xFFF7F3ED),
    },
    darkColors: {
      'primary': Color(0xFFE7A08A),
      'secondary': Color(0xFFF3B95F),
      'surface': Color(0xFF302925),
      'background': Color(0xFF211C19),
    },
    home: HomeOptions(
      showDailyWord: true,
      showStatistics: true,
      showExploreHeading: true,
      columns: 2,
    ),
  );
  static RemoteAppConfig get current => _current;

  static Future<void> load({
    http.Client? client,
    Uri? remoteUri,
    Duration timeout = _configTimeout,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final bundled = RemoteAppConfig.parse(
      await rootBundle.loadString(_configAsset),
    );
    _current = bundled;
    final cached = preferences.getString(_cacheKey);
    if (cached != null) {
      try {
        _current = RemoteAppConfig.parse(cached);
      } on FormatException {
        await preferences.remove(_cacheKey);
      }
    }
    appDataRevision.value++;
    unawaited(refresh(client: client, remoteUri: remoteUri, timeout: timeout));
  }

  /// Refreshes the snapshot; normally launched in the background by [load].
  static Future<void> refresh({
    http.Client? client,
    Uri? remoteUri,
    Duration timeout = _configTimeout,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await _refresh(
      preferences,
      client: client,
      remoteUri: remoteUri,
      timeout: timeout,
    );
  }

  static Future<void> _refresh(
    SharedPreferences preferences, {
    http.Client? client,
    Uri? remoteUri,
    Duration timeout = _configTimeout,
  }) async {
    try {
      final response =
          await (client?.get(remoteUri ?? Uri.parse(_configUrl)) ??
                  http.get(remoteUri ?? Uri.parse(_configUrl)))
              .timeout(timeout);
      if (response.statusCode != 200) {
        debugPrint(
          'Remote app config request returned HTTP ${response.statusCode}; '
          'using the last valid config.',
        );
        return;
      }
      final source = utf8.decode(response.bodyBytes);
      final validated = RemoteAppConfig.parse(source);
      await preferences.setString(_cacheKey, source);
      _current = validated;
      appDataRevision.value++;
    } on Object catch (error) {
      debugPrint(
        'Remote app config refresh failed; using last valid config: $error',
      );
    }
  }
}

const _icons = <String, IconData>{
  'menu_book_rounded': Icons.menu_book_rounded,
  'directions_run_rounded': Icons.directions_run_rounded,
  'auto_awesome_rounded': Icons.auto_awesome_rounded,
  'speed_rounded': Icons.speed_rounded,
  'auto_awesome_mosaic_rounded': Icons.auto_awesome_mosaic_rounded,
  'record_voice_over_rounded': Icons.record_voice_over_rounded,
  'category_rounded': Icons.category_rounded,
  'school_rounded': Icons.school_rounded,
};

Map<String, dynamic> _map(Object? value, String path) {
  if (value is! Map) throw FormatException('$path must be an object.');
  return Map<String, dynamic>.from(value);
}

void _keys(Map<String, dynamic> value, Set<String> allowed, String path) {
  if (value.keys.any((key) => !allowed.contains(key))) {
    throw FormatException('$path contains unsupported fields.');
  }
}

String _text(Object? value, String path, int maxLength) {
  if (value is! String || value.trim().isEmpty || value.length > maxLength) {
    throw FormatException(
      '$path must be non-empty text of at most $maxLength characters.',
    );
  }
  return value;
}

Color _color(Object? value, String path) {
  if (value is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
    throw FormatException('$path must be a #RRGGBB color.');
  }
  return Color(0xFF000000 | int.parse(value.substring(1), radix: 16));
}
