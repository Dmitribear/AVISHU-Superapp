import 'package:flutter_test/flutter_test.dart';

import 'package:avishu/features/orders/domain/enums/delivery_method.dart';
import 'package:avishu/features/users/domain/services/loyalty_program.dart';

void main() {
  test('pricing applies tier discount and bonus redemption', () {
    final pricing = LoyaltyProgram.pricing(
      subtotal: 80000,
      deliveryMethod: DeliveryMethod.courier,
      totalSpent: 180000,
      bonusBalance: 6000,
      applyTierDiscount: true,
      useBonusBalance: true,
    );

    expect(pricing.discountAmount, closeTo(5601.75, 0.001));
    expect(pricing.bonusRedeemed, 6000);
    expect(pricing.total, closeTo(68423.25, 0.001));
    expect(pricing.earnedBonus, closeTo(3421.1625, 0.001));
  });

  test('purchase updates spend and keeps bonus balance', () {
    final purchase = LoyaltyProgram.applyPurchase(
      totalSpent: 48000,
      bonusBalance: 4000,
      paidAmount: 52000,
      redeemedBonus: 2000,
    );

    expect(purchase.updatedTotalSpent, 100000);
    expect(purchase.updatedBonusBalance, 2000);
    expect(purchase.tierAfterPurchase.tier, LoyaltyTier.silk);
  });
}
