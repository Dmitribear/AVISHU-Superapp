import 'package:flutter/material.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../core/theme/typography.dart';

class AuthBrandBlock extends StatelessWidget {
  final String eyebrow;
  final double topSpacing;
  final double brandToEyebrowSpacing;

  const AuthBrandBlock({
    super.key,
    required this.eyebrow,
    required this.topSpacing,
    required this.brandToEyebrowSpacing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: topSpacing),
        Text(
          'AVISHU',
          style: AppTypography.brandMark.copyWith(
            fontSize: 28,
            letterSpacing: 8,
          ),
        ),
        SizedBox(height: brandToEyebrowSpacing),
        Text(
          eyebrow,
          textAlign: TextAlign.center,
          style: AppTypography.eyebrow.copyWith(color: AppColors.outline),
        ),
      ],
    );
  }
}
