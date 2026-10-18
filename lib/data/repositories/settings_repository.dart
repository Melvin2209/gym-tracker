import 'package:flutter/material.dart' show ThemeMode;

import '../db/app_database.dart';

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.defaultRestSeconds = 120,
    this.restNotifications = true,
    this.cloudSync = false,
    this.lastSyncedAt,
    this.remoteCursor,
  });

  final ThemeMode themeMode;
  final int defaultRestSeconds;
  final bool restNotifications;
  final bool cloudSync;
  final DateTime? lastSyncedAt;

  /// Server timestamp of the newest change pulled from the cloud.
  final int? remoteCursor;

  factory AppSettings.fromMap(Map<String, String> map) => AppSettings(
    themeMode: ThemeMode.values.asNameMap()[map['themeMode']] ?? ThemeMode.system,
    defaultRestSeconds: int.tryParse(map['defaultRestSeconds'] ?? '') ?? 120,
    restNotifications: map['restNotifications'] != 'false',
    cloudSync: map['cloudSync'] == 'true',
    lastSyncedAt: switch (int.tryParse(map['lastSyncedAt'] ?? '')) {
      final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
      null => null,
    },
    remoteCursor: int.tryParse(map['remoteCursor'] ?? ''),
  );
}

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Stream<AppSettings> watch() => _db
      .select(_db.settings)
      .watch()
      .map((rows) => AppSettings.fromMap({for (final r in rows) r.key: r.value}));

  Future<AppSettings> get() async {
    final rows = await _db.select(_db.settings).get();
    return AppSettings.fromMap({for (final r in rows) r.key: r.value});
  }

  Future<void> _put(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));

  Future<void> setThemeMode(ThemeMode mode) => _put('themeMode', mode.name);
  Future<void> setDefaultRest(int seconds) => _put('defaultRestSeconds', '$seconds');
  Future<void> setRestNotifications(bool enabled) => _put('restNotifications', '$enabled');
  Future<void> setCloudSync(bool enabled) => _put('cloudSync', '$enabled');
  Future<void> saveSyncCursor({required DateTime pushedUpTo, int? pulledUpTo}) async {
    await _put('lastSyncedAt', '${pushedUpTo.millisecondsSinceEpoch}');
    if (pulledUpTo != null) await _put('remoteCursor', '$pulledUpTo');
  }
}
