import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/typography.dart';
import '../../../../../shared/widgets/avishu_button.dart';
import '../../../data/auth_repository.dart';
import '../../../domain/user_role.dart';
import '../atoms/auth_input_field.dart';
import '../molecules/auth_role_option_card.dart';
import '../organisms/auth_access_shell.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  UserRole _selectedRole = UserRole.client;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showError('ЗАПОЛНИТЕ ВСЕ ПОЛЯ');
      return;
    }
    if (!email.contains('@')) {
      _showError('УКАЖИТЕ КОРРЕКТНЫЙ EMAIL');
      return;
    }
    if (password.length < 6) {
      _showError('ПАРОЛЬ ДОЛЖЕН БЫТЬ НЕ КОРОЧЕ 6 СИМВОЛОВ');
      return;
    }
    if (password != confirmPassword) {
      _showError('ПАРОЛИ НЕ СОВПАДАЮТ');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref
          .read(authRepositoryProvider)
          .register(
            email: email,
            password: password,
            role: _selectedRole,
            name: name,
          );
    } on FirebaseAuthException catch (error) {
      _showError(_mapAuthError(error.code));
    } catch (error) {
      _showError('ОШИБКА РЕГИСТРАЦИИ: $error');
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
      SnackBar(content: Text(message), backgroundColor: AppColors.black),
    );
  }

  String _mapAuthError(String code) {
    return switch (code) {
      'email-already-in-use' => 'ЭТОТ EMAIL УЖЕ ИСПОЛЬЗУЕТСЯ',
      'invalid-email' => 'EMAIL УКАЗАН В НЕВЕРНОМ ФОРМАТЕ',
      'weak-password' => 'ВЫБЕРИТЕ БОЛЕЕ НАДЕЖНЫЙ ПАРОЛЬ',
      'operation-not-allowed' => 'РЕГИСТРАЦИЯ ВРЕМЕННО НЕДОСТУПНА',
      _ => 'РЕГИСТРАЦИЯ НЕ УДАЛАСЬ: $code',
    };
  }

  String _roleLabel(UserRole role) {
    return switch (role) {
      UserRole.client => 'КЛИЕНТ',
      UserRole.franchisee => 'ФРАНЧАЙЗИ',
      UserRole.production => 'ЦЕХ',
      UserRole.admin => 'АДМИН',
    };
  }

  String _roleCaption(UserRole role) {
    return switch (role) {
      UserRole.client => 'Каталог, оформление заказа и живой трекинг.',
      UserRole.franchisee =>
        'Приём заказов, управление каталогом и отправка в работу.',
      UserRole.production => 'Очередь цеха, этапы пошива и завершение задач.',
      UserRole.admin => 'Доступ для внутреннего управления.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return AuthAccessShell(
      eyebrow: 'СОЗДАНИЕ АККАУНТА',
      topSpacing: 40,
      brandToEyebrowSpacing: 32,
      footerLabel: 'V.2.04 / NEW USER',
      footerIcons: const [
        Icons.person_add_outlined,
        Icons.verified_user_outlined,
      ],
      child: Column(
        children: [
          const SizedBox(height: 22),
          AuthInputField(
            controller: _nameController,
            label: 'ПОЛНОЕ ИМЯ',
            keyboardType: TextInputType.name,
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 12),
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
            onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 12),
          AuthInputField(
            controller: _confirmController,
            label: 'ПОВТОР ПАРОЛЯ',
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _register(),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ВЫБОР РОЛИ',
              style: AppTypography.eyebrow.copyWith(
                color: AppColors.outline,
                letterSpacing: 3,
              ),
            ),
          ),
          const SizedBox(height: 14),
          ...UserRole.registrationRoles.map(
            (role) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AuthRoleOptionCard(
                label: _roleLabel(role),
                caption: _roleCaption(role),
                isSelected: _selectedRole == role,
                onTap: () => setState(() => _selectedRole = role),
              ),
            ),
          ),
          const SizedBox(height: 20),
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
              text: 'ЗАРЕГИСТРИРОВАТЬ',
              expanded: true,
              variant: AvishuButtonVariant.filled,
              onPressed: _register,
            ),
          const SizedBox(height: 12),
          AvishuButton(
            text: 'НАЗАД КО ВХОДУ',
            expanded: true,
            variant: AvishuButtonVariant.ghost,
            onPressed: _isLoading ? null : () => context.go('/login'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
