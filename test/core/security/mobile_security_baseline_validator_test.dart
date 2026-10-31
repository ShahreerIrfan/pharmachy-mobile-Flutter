import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_security_baseline_validator.dart';

void main() {
  group('ADR-0060: Mobile Security Baseline Validator Tests', () {
    test('Cashier is confined to assigned branch', () {
      expect(
        MobileSecurityBaselineValidator.isBranchConfinementValid(
          userBranchId: 'branch-ctg-01',
          targetBranchId: 'branch-ctg-01',
          role: 'CASHIER',
        ),
        isTrue,
      );
      expect(
        MobileSecurityBaselineValidator.isBranchConfinementValid(
          userBranchId: 'branch-ctg-01',
          targetBranchId: 'branch-dhk-99',
          role: 'CASHIER',
        ),
        isFalse,
      );
      // Owner has chain-wide privilege
      expect(
        MobileSecurityBaselineValidator.isBranchConfinementValid(
          userBranchId: 'branch-ctg-01',
          targetBranchId: 'branch-dhk-99',
          role: 'PHARMACY_OWNER',
        ),
        isTrue,
      );
    });

    test('Cost price masking is verified for cashier vs manager', () {
      expect(
        MobileSecurityBaselineValidator.isCostPriceMaskingEnforced(
          role: 'CASHIER',
          rawCost: '320.00',
        ),
        isTrue,
      );
      expect(
        MobileSecurityBaselineValidator.isCostPriceMaskingEnforced(
          role: 'PHARMACY_OWNER',
          rawCost: '320.00',
        ),
        isTrue,
      );
    });

    test('Absolute deletion block on invoices is enforced', () {
      expect(
        MobileSecurityBaselineValidator.isDeletionBlocked(
          method: 'DELETE',
          path: '/api/v2/invoices/inv-01/',
        ),
        isTrue,
      );
    });

    test('Mobile security baseline report returns PASSED status', () {
      final report = MobileSecurityBaselineValidator.evaluateMobileBaseline(
        tenantId: 'tenant-ctg-01',
        userRole: 'PHARMACY_OWNER',
        branchId: 'branch-01',
        sampleCostPrice: '450.00',
      );

      expect(report.service, equals('pharmacy-mobile-manager'));
      expect(report.overallStatus, equals('PASSED'));
      expect(report.checksFailed, equals(0));
      expect(report.checksPassed, greaterThanOrEqualTo(4));
      expect(report.verifiedPillars.contains('AUTH_GATE'), isTrue);
      expect(report.verifiedPillars.contains('PRIVACY_GATE'), isTrue);
    });
  });
}
