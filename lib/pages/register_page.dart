import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../core/result.dart';
import '../domain/usecases/register_usecase.dart';
import '../services/form_cache_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FormCacheService _formCacheService = GetIt.I.get<FormCacheService>();
  bool _isLoading = false;

  bool _hasDisallowedCharacters(String value) {
    return RegExp(r'[^\x20-\x7E]').hasMatch(value);
  }

  Future<void> _restoreCachedDraft() async {
    final Map<String, String>? draft =
        await _formCacheService.getRegisterDraft();
    if (!mounted || draft == null) return;

    if (draft['name'] != null && draft['name']!.isNotEmpty) {
      _nameController.text = draft['name']!;
    }
    if (draft['email'] != null && draft['email']!.isNotEmpty) {
      _emailController.text = draft['email']!;
    }
    if (draft['password'] != null && draft['password']!.isNotEmpty) {
      _passwordController.text = draft['password']!;
    }
  }

  @override
  void initState() {
    super.initState();
    _restoreCachedDraft();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final RegisterUseCase useCase = GetIt.I.get<RegisterUseCase>();
    final Result<void> result = await useCase(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      await _formCacheService.clearRegisterDraft();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully')),
      );
      Navigator.pop(context, true);
    } else {
      final String error = result.error ?? 'Registration failed';
      final bool offline = error.toLowerCase().contains('network error');

      if (offline) {
        await _formCacheService.saveRegisterDraft(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Necesitas una conexión a internet para completar tu registro. Inténtalo nuevamente cuando tengas acceso.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 200,
                width: double.infinity,
                child: Image.asset('assets/img/login.png', fit: BoxFit.cover),
              ),
              const SizedBox(height: 20),
              Text(
                'Create your account',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: <Widget>[
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Name',
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (String? value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter your name';
                          }
                          if (_hasDisallowedCharacters(value)) {
                            return 'Remove emojis or invalid characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Email',
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (String? value) {
                          final String v = (value ?? '').trim();
                          if (v.isEmpty) return 'Enter your email';
                          final bool ok = RegExp(r'^.+@.+\..+?').hasMatch(v);
                          if (!ok) return 'Invalid email';
                          if (_hasDisallowedCharacters(v)) {
                            return 'Use standard email characters only';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        validator: (String? value) {
                          if ((value ?? '').length < 6) {
                            return 'Minimum 6 characters';
                          }
                          if (_hasDisallowedCharacters(value ?? '')) {
                            return 'Remove emojis or unsupported characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Create account',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
