import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../shared/widgets/avishu_button.dart';
import '../../../data/auth_repository.dart';
import '../atoms/auth_input_field.dart';
import '../organisms/auth_access_shell.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('ЗАПОЛНИТЕ ВСЕ ПОЛЯ');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
    } on FirebaseAuthException catch (error) {
      _showError(_mapAuthError(error.code));
    } catch (error) {
      _showError('ОШИБКА: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(letterSpacing: 1.5)),
        backgroundColor: AppColors.black,
      ),
    );
  }

  String _mapAuthError(String code) {
    return switch (code) {
      'user-not-found' => 'ПОЛЬЗОВАТЕЛЬ НЕ НАЙДЕН',
      'wrong-password' || 'invalid-credential' => 'НЕВЕРНЫЙ ПАРОЛЬ',
      'invalid-email' => 'НЕКОРРЕКТНЫЙ EMAIL',
      'user-disabled' => 'АККАУНТ ЗАБЛОКИРОВАН',
      'too-many-requests' => 'СЛИШКОМ МНОГО ПОПЫТОК. ПОДОЖДИТЕ',
      _ => 'ОШИБКА АВТОРИЗАЦИИ: $code',
    };
  }

  @override
  Widget build(BuildContext context) {
    return AuthAccessShell(
      eyebrow: 'АВТОРИЗАЦИЯ',
      topSpacing: 52,
      brandToEyebrowSpacing: 48,
      footerLabel: 'V.2.04 / SECURE ACCESS',
      footerIcons: const [Icons.shield_outlined, Icons.lock_outline],
      child: Column(
        children: [
          const SizedBox(height: 26),
          AuthInputField(
            controller: _emailController,
            label: 'EMAIL',
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 12),
          AuthInputField(
            controller: _passwordController,
            label: 'ПАРОЛЬ',
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _signIn(),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const SizedBox(
              height: 56,
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.black,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            AvishuButton(
              text: 'ВОЙТИ',
              expanded: true,
              variant: AvishuButtonVariant.filled,
              onPressed: _signIn,
            ),
          const SizedBox(height: 12),
          AvishuButton(
            text: 'РЕГИСТРАЦИЯ',
            expanded: true,
            variant: AvishuButtonVariant.ghost,
            onPressed: _isLoading ? null : () => context.go('/register'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
