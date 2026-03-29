import 'package:flutter/material.dart';

import '../../../../../core/theme/colors.dart';
import '../../../../../shared/widgets/corner_decoration.dart';
import '../atoms/auth_footer_strip.dart';
import '../molecules/auth_brand_block.dart';

class AuthAccessShell extends StatelessWidget {
  final String eyebrow;
  final double topSpacing;
  final double brandToEyebrowSpacing;
  final String footerLabel;
  final List<IconData> footerIcons;
  final Widget child;

  const AuthAccessShell({
    super.key,
    required this.eyebrow,
    required this.topSpacing,
    required this.brandToEyebrowSpacing,
    required this.footerLabel,
    required this.footerIcons,
    required this.child,
  });

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
                                AuthBrandBlock(
                                  eyebrow: eyebrow,
                                  topSpacing: topSpacing,
                                  brandToEyebrowSpacing: brandToEyebrowSpacing,
                                ),
                                child,
                              ],
                            ),
                          ),
                        ),
                        AuthFooterStrip(label: footerLabel, icons: footerIcons),
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
}
