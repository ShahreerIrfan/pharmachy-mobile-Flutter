// Architecture Decision: ADR-0270 (P270)
// Phase 14: Customers, Suppliers, Dues & Payments.
// Mobile Customer Loyalty Client for Manager/Owner Flutter App.

enum MobileLoyaltyTier {
  bronze,
  silver,
  gold,
  platinum,
}

class MobileCartItemForLoyalty {
  final String productName;
  final double lineTotalBdt;
  final bool isPrescriptionRequired;
  final bool isAntibiotic;
  final bool isNarcotic;

  const MobileCartItemForLoyalty({
    required this.productName,
    required this.lineTotalBdt,
    this.isPrescriptionRequired = false,
    this.isAntibiotic = false,
    this.isNarcotic = false,
  });

  bool get isRestricted => isPrescriptionRequired || isAntibiotic || isNarcotic;
}

class MobileCustomerLoyaltyClient {
  /// Splits spend into eligible vs DGDA-restricted spend and computes earnable points.
  static Map<String, dynamic> calculateSpendBreakdown({
    required List<MobileCartItemForLoyalty> items,
    required double earnRateBdtPerPoint,
  }) {
    double eligible = 0.0;
    double excluded = 0.0;

    for (final item in items) {
      if (item.isRestricted) {
        excluded += item.lineTotalBdt;
      } else {
        eligible += item.lineTotalBdt;
      }
    }

    final points = earnRateBdtPerPoint > 0 ? (eligible / earnRateBdtPerPoint).floor() : 0;

    return {
      'eligibleSpendBdt': eligible,
      'excludedSpendBdt': excluded,
      'pointsEarnable': points,
    };
  }

  /// Validates points redemption request.
  static Map<String, dynamic> validateRedemption({
    required int pointsToRedeem,
    required int currentPointsBalance,
    required int minPointsThreshold,
    required double eligibleSpendBdt,
    required double redemptionRateBdtPerPoint,
    required int maxRedemptionPercent,
  }) {
    if (pointsToRedeem <= 0) {
      return {'isValid': false, 'errorCode': 'ERR_POINTS_INVALID', 'message': 'Points must be positive.'};
    }

    if (pointsToRedeem < minPointsThreshold) {
      return {
        'isValid': false,
        'errorCode': 'ERR_MIN_POINTS_THRESHOLD',
        'message': 'Minimum $minPointsThreshold points required.',
      };
    }

    if (pointsToRedeem > currentPointsBalance) {
      return {
        'isValid': false,
        'errorCode': 'ERR_INSUFFICIENT_LOYALTY_POINTS',
        'message': 'Requested points exceed available balance ($currentPointsBalance).',
      };
    }

    if (eligibleSpendBdt <= 0.0) {
      return {
        'isValid': false,
        'errorCode': 'ERR_NO_ELIGIBLE_ITEMS',
        'message': 'Cart contains only restricted prescription/antibiotic items.',
      };
    }

    final discount = pointsToRedeem * redemptionRateBdtPerPoint;
    final maxAllowedDiscount = (eligibleSpendBdt * maxRedemptionPercent) / 100.0;

    if (discount > maxAllowedDiscount) {
      return {
        'isValid': false,
        'errorCode': 'ERR_MAX_REDEMPTION_EXCEEDED',
        'message': 'Discount exceeds max allowed percentage of eligible spend.',
      };
    }

    return {'isValid': true, 'errorCode': null, 'message': null};
  }
}
