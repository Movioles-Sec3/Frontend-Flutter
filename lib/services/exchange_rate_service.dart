import 'dart:convert';

import 'package:http/http.dart' as http;

class ExchangeRateService {
  ExchangeRateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Fetches exchange rates from ExchangeRate-API (public endpoint) using the given base currency
  /// Docs: https://www.exchangerate-api.com/docs/free
  /// Example endpoint without API key (open.er-api.com): https://open.er-api.com/v6/latest/COP
  Future<Map<String, double>> getRates(String baseCurrency) async {
    final Uri uri = Uri.parse('https://open.er-api.com/v6/latest/$baseCurrency');
    final http.Response res = await _client.get(uri);
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
  }
}


