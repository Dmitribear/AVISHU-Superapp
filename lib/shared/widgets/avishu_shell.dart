import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

class AvishuShell extends StatelessWidget {
  final String shellLabel;
  final String shellValue;
  final Widget child;
  final Widget? trailing;
  final Color backgroundColor;

  const AvishuShell({
    super.key,
    required this.shellLabel,
    required this.shellValue,
    required this.child,
    this.trailing,
    this.backgroundColor = AppColors.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 78,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(
                color: AppColors.surfaceLowest,
                border: Border(
                  bottom: BorderSide(color: AppColors.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text('AVISHU', style: AppTypography.brandMark),
                        const SizedBox(width: 18),
                        Container(
                          width: 1,
                          height: 26,
                          color: AppColors.outlineVariant,
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${shellLabel.toUpperCase()}  ',
                                  style: AppTypography.eyebrow,
                                ),
                                TextSpan(
                                  text: shellValue.toUpperCase(),
                                  style: AppTypography.eyebrow.copyWith(
                                    color: AppColors.black,
                                  ),
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
