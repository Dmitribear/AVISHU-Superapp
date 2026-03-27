import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../shared/widgets/avishu_button.dart';
import '../../../shared/widgets/corner_decoration.dart';
import '../data/auth_repository.dart';
import '../domain/user_role.dart';

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
  bool _loading = false;

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
    final confirm = _confirmController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showError('Fill in all fields.');
      return;
    }
    if (!email.contains('@')) {
      _showError('Enter a valid email.');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }
    if (password != confirm) {
      _showError('Passwords do not match.');
      return;
    }

    setState(() => _loading = true);

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
      _showError('Registration error: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
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
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'invalid-email':
        return 'Email format is invalid.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'operation-not-allowed':
        return 'Registration is currently disabled.';
      default:
        return 'Registration failed: $code';
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
                                const SizedBox(height: 40),
                                Text(
                                  'AVISHU',
                                  style: AppTypography.brandMark.copyWith(
                                    fontSize: 28,
                                    letterSpacing: 8,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Text(
                                  'CREATE ACCOUNT',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.eyebrow.copyWith(
                                    color: AppColors.outline,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                _buildTextField(
                                  controller: _nameController,
                                  label: 'FULL NAME',
                                  keyboardType: TextInputType.name,
                                ),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  controller: _emailController,
                                  label: 'EMAIL',
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  controller: _passwordController,
                                  label: 'PASSWORD',
                                  obscure: true,
                                ),
                                const SizedBox(height: 12),
                                _buildTextField(
                                  controller: _confirmController,
                                  label: 'CONFIRM PASSWORD',
                                  obscure: true,
                                ),
                                const SizedBox(height: 22),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'SELECT ROLE',
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
                                    child: _RoleOption(
                                      label: _roleLabel(role),
                                      caption: _roleCaption(role),
                                      isSelected: _selectedRole == role,
                                      onTap: () =>
                                          setState(() => _selectedRole = role),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
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
                                        text: 'REGISTER',
                                        expanded: true,
                                        variant: AvishuButtonVariant.filled,
                                        onPressed: _register,
                                      ),
                                const SizedBox(height: 12),
                                AvishuButton(
                                  text: 'BACK TO LOGIN',
                                  expanded: true,
                                  variant: AvishuButtonVariant.ghost,
                                  onPressed: _loading
                                      ? null
                                      : () => context.go('/login'),
                                ),
                                const SizedBox(height: 24),
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
                                'V.2.04 / NEW USER',
                                style: AppTypography.eyebrow,
                              ),
                              const SizedBox(height: 10),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_add_outlined,
                                    size: 16,
                                    color: AppColors.outline,
                                  ),
                                  SizedBox(width: 12),
                                  Icon(
                                    Icons.verified_user_outlined,
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
    );
  }

  String _roleLabel(UserRole role) {
    if (role == UserRole.client) {
      return 'CLIENT';
    }
    if (role == UserRole.franchisee) {
      return 'FRANCHISEE';
    }
    if (role == UserRole.production) {
      return 'FACTORY';
    }
    return 'ADMIN';
  }

  String _roleCaption(UserRole role) {
    if (role == UserRole.client) {
      return 'Catalog, checkout, and live order tracking.';
    }
    if (role == UserRole.franchisee) {
      return 'Accept incoming orders and send them to production.';
    }
    if (role == UserRole.production) {
      return 'See the factory queue and complete orders.';
    }
    return 'System access for demo control.';
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final String caption;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.caption,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.black : AppColors.surfaceLowest,
          border: Border.all(color: AppColors.black),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.button.copyWith(
                      letterSpacing: 3,
                      color: isSelected ? AppColors.white : AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    caption,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? AppColors.surfaceHighest
                          : AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.white : AppColors.black,
                  width: isSelected ? 5 : 1.5,
                ),
                color: isSelected ? AppColors.black : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
