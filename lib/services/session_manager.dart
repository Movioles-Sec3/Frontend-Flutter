import 'package:hive/hive.dart';

class SessionManager {
  static const String boxName = 'session_box';
  static const String _keyAccessToken = 'access_token';
  static const String _keyTokenType = 'token_type';

  static Future<void> saveToken({
    required String accessToken,
    required String tokenType,
  }) async {
    final Box<String> box = await _getBox();
    await box.put(_keyAccessToken, accessToken);
    await box.put(_keyTokenType, tokenType);
  }

  static Future<String?> getAccessToken() async {
    final Box<String> box = await _getBox();
    return box.get(_keyAccessToken);
  }

  static Future<String?> getTokenType() async {
    final Box<String> box = await _getBox();
    return box.get(_keyTokenType);
  }

  static Future<void> clear() async {
    final Box<String> box = await _getBox();
    await box.delete(_keyAccessToken);
    await box.delete(_keyTokenType);
  }

  static Future<Box<String>> _getBox() async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<String>(boxName);
    }
    return Hive.openBox<String>(boxName);
  }
}
