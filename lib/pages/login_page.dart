import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../domain/usecases/login_usecase.dart';
import '../core/result.dart';
import '../main.dart';
import 'register_page.dart';
import '../services/form_cache_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FormCacheService _formCacheService = GetIt.I.get<FormCacheService>();
  bool _isLoading = false;

  bool _hasDisallowedCharacters(String value) {
    return RegExp(r'[^\x20-\x7E]').hasMatch(value);
  }

  @override
  void initState() {
    super.initState();
    _restoreCachedDraft();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _restoreCachedDraft() async {
    final Map<String, String>? draft =
        await _formCacheService.getLoginDraft();
    if (!mounted || draft == null) return;

    if (draft['email'] != null && draft['email']!.isNotEmpty) {
      _emailController.text = draft['email']!;
    }
    if (draft['password'] != null && draft['password']!.isNotEmpty) {
      _passwordController.text = draft['password']!;
    }
  }

  Future<void> _login() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter email and password')));
      return;
    }

    if (_hasDisallowedCharacters(email) || _hasDisallowedCharacters(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remove emojis or invalid characters from email and password.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final LoginUseCase useCase = GetIt.I.get<LoginUseCase>();
    final Result<void> result = await useCase(email, password);

    if (!mounted) return;

    if (result.isSuccess) {
      await _formCacheService.clearLoginDraft();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const MyHomePage(title: 'Home'),
        ),
      );
    } else {
      final String error = result.error ?? 'Login failed';
      final bool offline = error.toLowerCase().contains('network error');

      if (offline) {
        await _formCacheService.saveLoginDraft(
          email: email,
          password: password,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Necesitas una conexión a internet para iniciar sesión. Conservamos tus datos para que lo intentes más tarde.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: 250,
                width: double.infinity,
                child: Image.asset("assets/img/login.png", fit: BoxFit.cover),
              ),

              const SizedBox(height: 20),

              Text(
                "Welcome Back",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        hintText: "Email",
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: "Password",
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
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
                        onPressed: _isLoading ? null : _login,
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
                                "Login",
                                style: TextStyle(fontSize: 16),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: const [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text("or"),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),

                    const SizedBox(height: 20),
                    _socialButton("Continue with Facebook"),
                    const SizedBox(height: 12),
                    _socialButton("Continue with Twitter"),
                    const SizedBox(height: 12),
                    _socialButton("Continue with SMS"),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account? "),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const RegisterPage(),
                              ),
                            );
                          },
                          child: Text(
                            "Sign up",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialButton(String text) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.grey.shade200,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {},
        child: Text(text, style: const TextStyle(color: Colors.black)),
      ),
    );
  }
}
