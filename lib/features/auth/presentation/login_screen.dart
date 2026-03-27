import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/avishu_button.dart';
import '../../../shared/widgets/corner_decoration.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

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

    setState(() => _loading = true);

    try {
      await ref.read(authRepositoryProvider).signIn(
            email: email,
            password: password,
          );
      // Router redirect will handle navigation
    } on FirebaseAuthException catch (e) {
      _showError(_mapAuthError(e.code));
    } catch (e) {
      _showError('ОШИБКА: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(letterSpacing: 1.5)),
        backgroundColor: AppColors.black,
      ),
    );
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'ПОЛЬЗОВАТЕЛЬ НЕ НАЙДЕН';
      case 'wrong-password':
      case 'invalid-credential':
        return 'НЕВЕРНЫЙ ПАРОЛЬ';
      case 'invalid-email':
        return 'НЕКОРРЕКТНЫЙ EMAIL';
      case 'user-disabled':
        return 'АККАУНТ ЗАБЛОКИРОВАН';
      case 'too-many-requests':
        return 'СЛИШКОМ МНОГО ПОПЫТОК. ПОДОЖДИТЕ';
      default:
        return 'ОШИБКА АВТОРИЗАЦИИ: $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                const SizedBox(height: 52),
                                Text(
                                  'AVISHU',
                                  style: AppTypography.brandMark.copyWith(
                                    fontSize: 28,
                                    letterSpacing: 8,
                                  ),
                                ),
                                const SizedBox(height: 48),
                                Text(
                                  'АВТОРИЗАЦИЯ',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.eyebrow.copyWith(
                                    color: AppColors.outline,
                                  ),
                                ),
                                const SizedBox(height: 26),
                                _buildTextField(
                                  controller: _emailController,
                                  label: 'EMAIL',
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  controller: _passwordController,
                                  label: 'ПАРОЛЬ',
                                  obscure: true,
                                ),
                                const SizedBox(height: 24),
                                _loading
                                    ? const SizedBox(
                                        height: 56,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: AppColors.black,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : AvishuButton(
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
                                  onPressed: _loading
                                      ? null
                                      : () => context.go('/register'),
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(top: 16),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: AppColors.outlineVariant),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'V.2.04 / SECURE_ACCESS',
                                style: AppTypography.eyebrow,
                              ),
                              const SizedBox(height: 10),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    size: 16,
                                    color: AppColors.outline,
                                  ),
                                  SizedBox(width: 12),
                                  Icon(
                                    Icons.lock_outline,
                                    size: 16,
                                    color: AppColors.outline,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Positioned(
                    top: 0,
                    left: 0,
                    child: CornerDecoration(top: true, left: true),
                  ),
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: CornerDecoration(top: true, left: false),
                  ),
                  const Positioned(
                    bottom: 0,
                    left: 0,
                    child: CornerDecoration(top: false, left: true),
                  ),
                  const Positioned(
                    bottom: 0,
                    right: 0,
                    child: CornerDecoration(top: false, left: false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: AppTypography.button.copyWith(
        letterSpacing: 2,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.eyebrow.copyWith(color: AppColors.outline),
      ),
      onSubmitted: (_) {
        if (!obscure) {
          FocusScope.of(context).nextFocus();
        } else {
          _signIn();
        }
      },
    );
  }
}
