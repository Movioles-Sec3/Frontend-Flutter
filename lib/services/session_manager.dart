import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keyAccessToken = 'access_token';
  static const String _keyTokenType = 'token_type';

  static Future<void> saveToken({
    required String accessToken,
    required String tokenType,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyTokenType, tokenType);
  }

  static Future<String?> getAccessToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  static Future<String?> getTokenType() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTokenType);
  }

  static Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyTokenType);
  }
}
