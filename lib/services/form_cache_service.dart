import 'dart:convert';

import '../core/strategies/caching_strategy.dart';

/// Utility service to persist form data using the app cache context.
/// The underlying memory cache works as an LRU so the most recent drafts survive.
class FormCacheService {
  FormCacheService(this._cacheStrategy);

  static const String _registerKey = 'form_register';
  static const String _loginKey = 'form_login';

  final CachingStrategy<String> _cacheStrategy;

  Future<void> saveRegisterDraft({
    required String name,
    required String email,
    required String password,
  }) async {
    final String payload = jsonEncode({
      'name': name,
      'email': email,
      'password': password,
    });
    await _cacheStrategy.store(_registerKey, payload);
  }

  Future<Map<String, String>?> getRegisterDraft() async {
    final CacheResult<String> result = await _cacheStrategy.retrieve(_registerKey);
    if (!result.success || result.data == null) {
      return null;
    }

    final Map<String, dynamic> decoded =
        jsonDecode(result.data!) as Map<String, dynamic>;
    return decoded.map(
      (String key, dynamic value) => MapEntry(key, value?.toString() ?? ''),
    );
  }

  Future<void> clearRegisterDraft() async {
    await _cacheStrategy.remove(_registerKey);
  }

  Future<void> saveLoginDraft({
    required String email,
    required String password,
  }) async {
    final String payload = jsonEncode({
      'email': email,
      'password': password,
    });
    await _cacheStrategy.store(_loginKey, payload);
  }

  Future<Map<String, String>?> getLoginDraft() async {
    final CacheResult<String> result = await _cacheStrategy.retrieve(_loginKey);
    if (!result.success || result.data == null) {
      return null;
    }

    final Map<String, dynamic> decoded =
        jsonDecode(result.data!) as Map<String, dynamic>;
    return decoded.map(
      (String key, dynamic value) => MapEntry(key, value?.toString() ?? ''),
    );
  }

  Future<void> clearLoginDraft() async {
    await _cacheStrategy.remove(_loginKey);
  }
}
