import 'package:flutter/material.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/typography.dart';

class AuthFooterStrip extends StatelessWidget {
  final String label;
  final List<IconData> icons;

  const AuthFooterStrip({super.key, required this.label, required this.icons});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Column(
        children: [
          Text(label, style: AppTypography.eyebrow),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: icons.indexed.expand<Widget>((entry) {
              final index = entry.$1;
              final icon = entry.$2;
              return [
                Icon(icon, size: 16, color: AppColors.outline),
                if (index != icons.length - 1) const SizedBox(width: 12),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }
}
