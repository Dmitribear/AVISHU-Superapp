import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

class AvishuButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const AvishuButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.black,
        backgroundColor: AppColors.white,
        side: const BorderSide(color: AppColors.black, width: 1),
        shape: const BeveledRectangleBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      onPressed: onPressed,
      child: Text(text.toUpperCase(), style: AppTypography.brutalistButton),
    );
  }
}
