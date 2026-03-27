import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';

class AvishuNavItem {
  final String label;
  final IconData icon;

  const AvishuNavItem({
    required this.label,
    required this.icon,
  });
}

class AvishuMobileFrame extends StatelessWidget {
  final String title;
  final Widget body;
  final List<AvishuNavItem> navItems;
  final int currentIndex;
  final ValueChanged<int> onNavSelected;
  final IconData leadingIcon;
  final VoidCallback? onLeadingTap;
  final IconData actionIcon;
  final VoidCallback? onActionTap;
  final String? metaLabel;
  final bool showBottomNav;

  const AvishuMobileFrame({
    super.key,
    required this.title,
    required this.body,
    required this.navItems,
    required this.currentIndex,
    required this.onNavSelected,
    this.leadingIcon = Icons.menu_rounded,
    this.onLeadingTap,
    this.actionIcon = Icons.shopping_bag_outlined,
    this.onActionTap,
    this.metaLabel,
    this.showBottomNav = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.outlineVariant),
                  right: BorderSide(color: AppColors.outlineVariant),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    height: 72,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceLowest,
                      border: Border(
                        bottom: BorderSide(color: AppColors.outlineVariant),
                      ),
                    ),
                    child: Row(
                      children: [
                        _FrameIconButton(
                          icon: leadingIcon,
                          onTap: onLeadingTap,
                        ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                title,
                                style: AppTypography.brandMark.copyWith(
                                  fontSize: 22,
                                  letterSpacing: 4,
                                ),
                              ),
                              if (metaLabel != null) ...[
                                const SizedBox(height: 4),
                                Text(metaLabel!, style: AppTypography.eyebrow),
                              ],
                            ],
                          ),
                        ),
                        _FrameIconButton(
                          icon: actionIcon,
                          onTap: onActionTap,
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: body),
                  if (showBottomNav)
                    Container(
                      height: 80,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceLowest,
                        border: Border(
                          top: BorderSide(color: AppColors.outlineVariant),
                        ),
                      ),
                      child: Row(
                        children: List.generate(navItems.length, (index) {
                          final item = navItems[index];
                          final isActive = currentIndex == index;

                          return Expanded(
                            child: InkWell(
                              onTap: () => onNavSelected(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                color: isActive
                                    ? AppColors.black
                                    : AppColors.surfaceLowest,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      item.icon,
                                      size: 20,
                                      color: isActive
                                          ? AppColors.white
                                          : AppColors.black,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.label,
                                      textAlign: TextAlign.center,
                                      style: AppTypography.eyebrow.copyWith(
                                        color: isActive
                                            ? AppColors.white
                                            : AppColors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
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

class _FrameIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _FrameIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Icon(icon, size: 20, color: AppColors.black),
        ),
      ),
    );
  }
}
