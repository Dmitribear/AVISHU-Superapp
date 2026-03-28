import 'package:flutter/material.dart';

import '../atoms/client_surface_card.dart';

class ClientCheckoutLoyaltySection extends StatelessWidget {
  final bool compact;
  final String title;
  final String summary;
  final bool isDiscountApplied;
  final bool canApplyDiscount;
  final ValueChanged<bool>? onDiscountChanged;
  final String discountTitle;
  final String discountSubtitle;
  final bool isBonusApplied;
  final bool canUseBonus;
  final ValueChanged<bool>? onBonusChanged;
  final String bonusTitle;
  final String bonusSubtitle;

  const ClientCheckoutLoyaltySection({
    super.key,
    required this.compact,
    required this.title,
    required this.summary,
    required this.isDiscountApplied,
    required this.canApplyDiscount,
    required this.onDiscountChanged,
    required this.discountTitle,
    required this.discountSubtitle,
    required this.isBonusApplied,
    required this.canUseBonus,
    required this.onBonusChanged,
    required this.bonusTitle,
    required this.bonusSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ClientSurfaceCard(
      compact: compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(summary, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: isDiscountApplied && canApplyDiscount,
            onChanged: canApplyDiscount ? onDiscountChanged : null,
            title: Text(discountTitle),
            subtitle: Text(discountSubtitle),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: isBonusApplied && canUseBonus,
            onChanged: canUseBonus ? onBonusChanged : null,
            title: Text(bonusTitle),
            subtitle: Text(bonusSubtitle),
          ),
        ],
      ),
    );
  }
}
