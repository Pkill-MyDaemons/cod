import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/config.dart';

class ConfigNotifier extends Notifier<AppConfig> {
  @override
  AppConfig build() {
    Future.microtask(_load);
    return AppConfig.defaults;
  }

  static const _prefActiveProvider = 'active_provider';
  static String _prefKey(String provider) => 'key_$provider';
  static String _prefModel(String provider) => 'model_$provider';
  static String _prefBaseUrl(String provider) => 'base_$provider';

  // One-shot migration: copy settings from the old sandboxed plist (used by
  // versions before v1.4.0 which ran with App Sandbox enabled).
  Future<void> _migrateFromSandbox(SharedPreferences prefs) async {
    if (Platform.isIOS || Platform.isAndroid) return;
    final home = Platform.environment['HOME'] ?? '';
    final plist =
        '$home/Library/Containers/com.henry.cod/Data/Library/Preferences/com.henry.cod.plist';
    if (!await File(plist).exists()) return;
    try {
      final r = await Process.run('plutil', ['-convert', 'json', '-o', '-', plist]);
      if (r.exitCode != 0) return;
      final data = jsonDecode(r.stdout as String) as Map<String, dynamic>;
      for (final entry in data.entries) {
        if (entry.value is String) {
          await prefs.setString(entry.key, entry.value as String);
        }
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // Migrate old sandboxed settings if this is the first run without sandbox.
    if (prefs.getString(_prefActiveProvider) == null) {
      await _migrateFromSandbox(prefs);
    }
    final activeId = prefs.getString(_prefActiveProvider) ?? 'claude';
    final providers = Map<String, ProviderConfig>.from(state.providers);
    for (final id in providers.keys) {
      final key = prefs.getString(_prefKey(id)) ?? '';
      final model = prefs.getString(_prefModel(id)) ?? providers[id]!.selectedModel;
      final base = prefs.getString(_prefBaseUrl(id)) ?? providers[id]!.baseUrl;
      providers[id] = providers[id]!.copyWith(apiKey: key, selectedModel: model, baseUrl: base);
    }
    state = AppConfig(activeProviderId: activeId, providers: providers);
  }

  Future<void> setActiveProvider(String id) async {
    state = state.copyWith(activeProviderId: id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefActiveProvider, id);
  }

  Future<void> setApiKey(String providerId, String key) async {
    final providers = Map<String, ProviderConfig>.from(state.providers);
    providers[providerId] = providers[providerId]!.copyWith(apiKey: key);
    state = state.copyWith(providers: providers);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey(providerId), key);
  }

  Future<void> setModel(String providerId, String model) async {
    final providers = Map<String, ProviderConfig>.from(state.providers);
    providers[providerId] = providers[providerId]!.copyWith(selectedModel: model);
    state = state.copyWith(providers: providers);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefModel(providerId), model);
  }

  Future<void> setBaseUrl(String providerId, String url) async {
    final providers = Map<String, ProviderConfig>.from(state.providers);
    providers[providerId] = providers[providerId]!.copyWith(baseUrl: url);
    state = state.copyWith(providers: providers);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefBaseUrl(providerId), url);
  }
}
