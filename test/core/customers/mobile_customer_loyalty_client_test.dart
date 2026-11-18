import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/customers/mobile_customer_loyalty_client.dart';

void main() {
  group('MobileCustomerLoyaltyClient Tests (P270)', () {
    test('calculateSpendBreakdown excludes Rx and antibiotic medicines from earning points', () {
      final items = [
        const MobileCartItemForLoyalty(
          productName: 'Paracetamol 500mg OTC',
          lineTotalBdt: 300.0,
          isPrescriptionRequired: false,
        ),
        const MobileCartItemForLoyalty(
          productName: 'Amoxicillin 500mg Antibiotic',
          lineTotalBdt: 500.0,
          isPrescriptionRequired: true,
          isAntibiotic: true,
        ),
        const MobileCartItemForLoyalty(
          productName: 'Vitamin C Supplement',
          lineTotalBdt: 200.0,
          isPrescriptionRequired: false,
        ),
      ];

      final res = MobileCustomerLoyaltyClient.calculateSpendBreakdown(
        items: items,
        earnRateBdtPerPoint: 100.0,
      );

      expect(res['eligibleSpendBdt'], equals(500.0)); // 300 + 200
      expect(res['excludedSpendBdt'], equals(500.0)); // 500 antibiotic
      expect(res['pointsEarnable'], equals(5)); // 500 // 100
    });

    test('validateRedemption enforces min points and max percentage rules', () {
      final validRes = MobileCustomerLoyaltyClient.validateRedemption(
        pointsToRedeem: 20,
        currentPointsBalance: 50,
        minPointsThreshold: 10,
        eligibleSpendBdt: 1000.0,
        redemptionRateBdtPerPoint: 1.0,
        maxRedemptionPercent: 50,
      );
      expect(validRes['isValid'], isTrue);

      final belowMin = MobileCustomerLoyaltyClient.validateRedemption(
        pointsToRedeem: 5,
        currentPointsBalance: 50,
        minPointsThreshold: 10,
        eligibleSpendBdt: 1000.0,
        redemptionRateBdtPerPoint: 1.0,
        maxRedemptionPercent: 50,
      );
      expect(belowMin['isValid'], isFalse);
      expect(belowMin['errorCode'], equals('ERR_MIN_POINTS_THRESHOLD'));

      final exceedsCap = MobileCustomerLoyaltyClient.validateRedemption(
        pointsToRedeem: 600,
        currentPointsBalance: 1000,
        minPointsThreshold: 10,
        eligibleSpendBdt: 1000.0, // 50% max is 500 BDT
        redemptionRateBdtPerPoint: 1.0,
        maxRedemptionPercent: 50,
      );
      expect(exceedsCap['isValid'], isFalse);
      expect(exceedsCap['errorCode'], equals('ERR_MAX_REDEMPTION_EXCEEDED'));
    });
  });
}
