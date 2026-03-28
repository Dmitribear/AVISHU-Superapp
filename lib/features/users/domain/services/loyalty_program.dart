import '../../../orders/domain/enums/delivery_method.dart';
import '../../../../shared/i18n/app_localization.dart';

enum LoyaltyTier { starter, silk, atelier, maison }

class LoyaltyTierBenefits {
  final LoyaltyTier tier;
  final double threshold;
  final double bonusRate;
  final double discountRate;
  final bool freeCourier;

  const LoyaltyTierBenefits({
    required this.tier,
    required this.threshold,
    required this.bonusRate,
    required this.discountRate,
    required this.freeCourier,
  });

  String titleFor(AppLanguage language) {
    switch (tier) {
      case LoyaltyTier.starter:
        return tr(language, ru: 'START', en: 'START', kk: 'БАСТАУ');
      case LoyaltyTier.silk:
        return 'SILK';
      case LoyaltyTier.atelier:
        return 'ATELIER';
      case LoyaltyTier.maison:
        return 'MAISON';
    }
  }

  String perksFor(AppLanguage language) {
    switch (tier) {
      case LoyaltyTier.starter:
        return tr(
          language,
          ru: 'Копите сумму покупок для первого уровня.',
          en: 'Accumulate spend to unlock the first level.',
          kk: 'Бірінші деңгейді ашу үшін сатып алу сомасын жинаңыз.',
        );
      case LoyaltyTier.silk:
        return tr(
          language,
          ru: '5% скидка на следующий заказ и 3% бонусами.',
          en: '5% off the next order and 3% back in bonuses.',
          kk: 'Келесі тапсырысқа 5% жеңілдік және 3% бонус.',
        );
      case LoyaltyTier.atelier:
        return tr(
          language,
          ru: '7% скидка на заказ и 5% бонусами.',
          en: '7% off each order and 5% back in bonuses.',
          kk: 'Әр тапсырысқа 7% жеңілдік және 5% бонус.',
        );
      case LoyaltyTier.maison:
        return tr(
          language,
          ru: '10% скидка, 7% бонусами и бесплатная курьерская доставка.',
          en: '10% off, 7% back in bonuses, and free courier delivery.',
          kk: '10% жеңілдік, 7% бонус және тегін курьерлік жеткізу.',
        );
    }
  }
}

class LoyaltyProfileSnapshot {
  final LoyaltyTierBenefits currentTier;
  final LoyaltyTierBenefits? nextTier;
  final double totalSpent;
  final double bonusBalance;
  final double progressToNextTier;
  final double amountToNextTier;

  const LoyaltyProfileSnapshot({
    required this.currentTier,
    required this.nextTier,
    required this.totalSpent,
    required this.bonusBalance,
    required this.progressToNextTier,
    required this.amountToNextTier,
  });
}

class LoyaltyCheckoutPricing {
  final LoyaltyTierBenefits tier;
  final double subtotal;
  final double deliveryFee;
  final double discountAmount;
  final double bonusRedeemed;
  final double total;
  final double earnedBonus;
  final double courierSavings;

  const LoyaltyCheckoutPricing({
    required this.tier,
    required this.subtotal,
    required this.deliveryFee,
    required this.discountAmount,
    required this.bonusRedeemed,
    required this.total,
    required this.earnedBonus,
    required this.courierSavings,
  });
}

class LoyaltyPurchaseResult {
  final double updatedTotalSpent;
  final double updatedBonusBalance;
  final double earnedBonus;
  final LoyaltyTierBenefits tierBeforePurchase;
  final LoyaltyTierBenefits tierAfterPurchase;

  const LoyaltyPurchaseResult({
    required this.updatedTotalSpent,
    required this.updatedBonusBalance,
    required this.earnedBonus,
    required this.tierBeforePurchase,
    required this.tierAfterPurchase,
  });
}

class LoyaltyProgram {
  static const List<LoyaltyTierBenefits> tiers = <LoyaltyTierBenefits>[
    LoyaltyTierBenefits(
      tier: LoyaltyTier.starter,
      threshold: 0,
      bonusRate: 0,
      discountRate: 0,
      freeCourier: false,
    ),
    LoyaltyTierBenefits(
      tier: LoyaltyTier.silk,
      threshold: 50000,
      bonusRate: 0.03,
      discountRate: 0.05,
      freeCourier: false,
    ),
    LoyaltyTierBenefits(
      tier: LoyaltyTier.atelier,
      threshold: 150000,
      bonusRate: 0.05,
      discountRate: 0.07,
      freeCourier: false,
    ),
    LoyaltyTierBenefits(
      tier: LoyaltyTier.maison,
      threshold: 300000,
      bonusRate: 0.07,
      discountRate: 0.10,
      freeCourier: true,
    ),
  ];

  static LoyaltyTierBenefits benefitsForTotalSpent(double totalSpent) {
    var resolved = tiers.first;
    for (final tier in tiers) {
      if (totalSpent >= tier.threshold) {
        resolved = tier;
      }
    }
    return resolved;
  }

  static LoyaltyProfileSnapshot profileSnapshot({
    required double totalSpent,
    required double bonusBalance,
  }) {
    final tier = benefitsForTotalSpent(totalSpent);
    LoyaltyTierBenefits? nextTier;
    for (final candidate in tiers) {
      if (candidate.threshold > tier.threshold) {
        nextTier = candidate;
        break;
      }
    }

    if (nextTier == null) {
      return LoyaltyProfileSnapshot(
        currentTier: tier,
        nextTier: null,
        totalSpent: totalSpent,
        bonusBalance: bonusBalance,
        progressToNextTier: 1,
        amountToNextTier: 0,
      );
    }

    final range = nextTier.threshold - tier.threshold;
    final progress = range <= 0 ? 1 : ((totalSpent - tier.threshold) / range);

    return LoyaltyProfileSnapshot(
      currentTier: tier,
      nextTier: nextTier,
      totalSpent: totalSpent,
      bonusBalance: bonusBalance,
      progressToNextTier: progress.clamp(0.0, 1.0).toDouble(),
      amountToNextTier: (nextTier.threshold - totalSpent).clamp(
        0.0,
        double.infinity,
      ),
    );
  }

  static LoyaltyCheckoutPricing pricing({
    required double subtotal,
    required DeliveryMethod deliveryMethod,
    required double totalSpent,
    required double bonusBalance,
    required bool applyTierDiscount,
    required bool useBonusBalance,
  }) {
    final tier = benefitsForTotalSpent(totalSpent);
    final courierSavings =
        tier.freeCourier && deliveryMethod == DeliveryMethod.courier
        ? deliveryMethod.fee
        : 0.0;
    final deliveryFee = (deliveryMethod.fee - courierSavings).clamp(
      0.0,
      double.infinity,
    );
    final gross = subtotal + deliveryFee;
    final discountAmount = applyTierDiscount ? gross * tier.discountRate : 0.0;
    final afterDiscount = (gross - discountAmount).clamp(0.0, double.infinity);
    final bonusRedeemed = useBonusBalance
        ? bonusBalance.clamp(0.0, afterDiscount)
        : 0.0;
    final total = (afterDiscount - bonusRedeemed).clamp(0.0, double.infinity);
    final earnedBonus = total * tier.bonusRate;

    return LoyaltyCheckoutPricing(
      tier: tier,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      discountAmount: discountAmount,
      bonusRedeemed: bonusRedeemed,
      total: total,
      earnedBonus: earnedBonus,
      courierSavings: courierSavings,
    );
  }

  static LoyaltyPurchaseResult applyPurchase({
    required double totalSpent,
    required double bonusBalance,
    required double paidAmount,
    required double redeemedBonus,
  }) {
    final tierBefore = benefitsForTotalSpent(totalSpent);
    final earnedBonus = paidAmount * tierBefore.bonusRate;
    final updatedTotalSpent = totalSpent + paidAmount;
    final updatedBonusBalance =
        (bonusBalance - redeemedBonus).clamp(0.0, double.infinity) +
        earnedBonus;

    return LoyaltyPurchaseResult(
      updatedTotalSpent: updatedTotalSpent,
      updatedBonusBalance: updatedBonusBalance,
      earnedBonus: earnedBonus,
      tierBeforePurchase: tierBefore,
      tierAfterPurchase: benefitsForTotalSpent(updatedTotalSpent),
    );
  }
}
