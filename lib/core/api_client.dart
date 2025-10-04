import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/session_manager.dart';
import 'result.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final Map<String, String> base = <String, String>{
      'Accept': 'application/json',
    };
    if (auth) {
      final String? token = await SessionManager.getAccessToken();
      if (token != null && token.isNotEmpty) {
        final String type = (await SessionManager.getTokenType()) ?? 'Bearer';
        base['Authorization'] = '$type $token';
      }
    }
    return base;
  }

  Future<Result<dynamic>> get(String path, {bool auth = false}) async {
    try {
      final http.Response res = await _client.get(
        _uri(path),
        headers: await _headers(auth: auth),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return Result.success(jsonDecode(res.body));
      }
      return Result.failure(_extractError(res.body) ?? 'Request failed');
    } catch (e) {
      return Result.failure('Network error: $e');
    }
  }

  Future<Result<dynamic>> post(
    String path, {
    Object? body,
    bool auth = false,
  }) async {
    try {
      final Map<String, String> headers = await _headers(auth: auth);
      headers['Content-Type'] = 'application/json';
      final http.Response res = await _client.post(
        _uri(path),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return Result.success(res.body.isEmpty ? null : jsonDecode(res.body));
      }
      return Result.failure(_extractError(res.body) ?? 'Request failed');
    } catch (e) {
      return Result.failure('Network error: $e');
    }
  }

  String? _extractError(String body) {
    try {
      final dynamic data = jsonDecode(body);
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
    } catch (_) {}
    return null;
  }
}
