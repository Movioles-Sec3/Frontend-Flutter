import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'connectivity_service.dart';

class ExchangeRateService {
  ExchangeRateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 10);

  /// Fetches exchange rates from ExchangeRate-API (public endpoint) using the given base currency
  /// Docs: https://www.exchangerate-api.com/docs/free
  /// Example endpoint without API key (open.er-api.com): https://open.er-api.com/v6/latest/COP
  /// Throws an exception if offline or if the request fails
  Future<Map<String, double>> getRates(String baseCurrency) async {
    // Check connectivity first
    await ConnectivityService.instance.initialize();
    final bool isOnline = ConnectivityService.instance.isOnline;

    if (!isOnline) {
      throw Exception('No internet connection. Please check your connection and try again.');
    }

    final Uri uri = Uri.parse('https://open.er-api.com/v6/latest/$baseCurrency');

    try {
      final http.Response res = await _client.get(uri).timeout(
        _timeout,
        onTimeout: () {
          throw TimeoutException('Connection timed out. Please check your internet connection.');
        },
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Exchange rate request failed (${res.statusCode})');
      }

      final dynamic data = jsonDecode(res.body);
      if (data is! Map || data['result'] != 'success' || data['rates'] is! Map) {
        throw Exception('Invalid exchange rate response');
      }

      final Map<String, dynamic> rates = Map<String, dynamic>.from(data['rates'] as Map);
      return <String, double>{
        'USD': (rates['USD'] as num?)?.toDouble() ?? 0,
        'EUR': (rates['EUR'] as num?)?.toDouble() ?? 0,
        'MXN': (rates['MXN'] as num?)?.toDouble() ?? 0,
        baseCurrency.toUpperCase(): 1.0,
      };
    } on TimeoutException {
      throw Exception('Connection timed out. Please check your internet connection.');
    } catch (e) {
      // Check if it's a socket exception (network error)
      if (e.toString().toLowerCase().contains('socket') ||
          e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('failed host lookup')) {
        throw Exception('No internet connection. Please check your connection and try again.');
      }
      rethrow;
    }
  }
}


