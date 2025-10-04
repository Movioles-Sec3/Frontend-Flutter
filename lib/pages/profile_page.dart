import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/session_manager.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final String? token = await SessionManager.getAccessToken();
    final String tokenType = (await SessionManager.getTokenType()) ?? 'Bearer';
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        (Route<dynamic> _) => false,
      );
      return;
    }

    try {
      final Uri url = Uri.parse('${ApiConfig.baseUrl}/usuarios/me');
      final http.Response res = await http.get(
        url,
        headers: <String, String>{
          'Authorization': '$tokenType $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final dynamic data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          setState(() {
            _user = data;
            _loading = false;
          });
        } else {
          setState(() {
            _error = 'Invalid server response';
            _loading = false;
          });
        }
      } else {
        String message = 'Could not fetch profile';
        try {
          final dynamic data = jsonDecode(res.body);
          if (data is Map && data['detail'] != null) {
            message = data['detail'].toString();
          }
        } catch (_) {}
        setState(() {
          _error = message;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await SessionManager.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (Route<dynamic> _) => false,
    );
  }

  Future<void> _showRechargeDialog() async {
    final TextEditingController amountCtrl = TextEditingController();
    final double? amount = await showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add funds'),
          content: TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Amount'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final String raw = amountCtrl.text.trim().replaceAll(',', '.');
                final double? parsed = double.tryParse(raw);
                if (parsed == null || parsed <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid amount')),
                  );
                  return;
                }
                Navigator.of(context).pop(parsed);
              },
              child: const Text('Add funds'),
            ),
          ],
        );
      },
    );

    if (amount != null) {
      await _recharge(amount);
    }
  }

  Future<void> _recharge(double amount) async {
    try {
      final String? token = await SessionManager.getAccessToken();
      final String tokenType =
          (await SessionManager.getTokenType()) ?? 'Bearer';
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const LoginPage()),
          (Route<dynamic> _) => false,
        );
        return;
      }

      final Uri url = Uri.parse('${ApiConfig.baseUrl}/usuarios/me/recargar');
      final http.Response res = await http.post(
        url,
        headers: <String, String>{
          'Authorization': '$tokenType $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{'monto': amount}),
      );

      if (!mounted) return;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final dynamic data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          setState(() {
            _user = data;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Funds added')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid server response')),
          );
        }
      } else {
        String message = 'Could not add funds';
        try {
          final dynamic data = jsonDecode(res.body);
          if (data is Map && data['detail'] != null) {
            message = data['detail'].toString();
          }
        } catch (_) {}
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Network error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final Map<String, dynamic> user = _user ?? <String, dynamic>{};
    final String nombre = (user['nombre'] ?? '').toString();
    final String email = (user['email'] ?? '').toString();
    final String id = (user['id'] ?? '').toString();
    final String saldo = (user['saldo'] ?? '').toString();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            CircleAvatar(
              radius: 40,
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                nombre.isEmpty ? 'User' : nombre,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('ID'),
                    subtitle: Text(id),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email'),
                    subtitle: Text(email),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: const Text('Balance'),
                    subtitle: Text(saldo),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _showRechargeDialog,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Add funds'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
