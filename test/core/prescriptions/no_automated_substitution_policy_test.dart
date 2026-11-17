import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/no_automated_substitution_policy.dart';

void main() {
  group('NoAutomatedSubstitutionPolicy Tests (P250)', () {
    test('Statutory disclaimers and role authorizations', () {
      final en = NoAutomatedSubstitutionPolicy.getDisclaimer('en');
      expect(en, contains('administrative workflow system'));
      expect(en, contains('does not provide medical diagnoses'));

      final bn = NoAutomatedSubstitutionPolicy.getDisclaimer('bn');
      expect(bn, contains('প্রশাসনিক ওয়ার্কফ্লো'));
      expect(bn, contains('স্বয়ংক্রিয় ওষুধ পরিবর্তন'));

      expect(NoAutomatedSubstitutionPolicy.isRoleAuthorized('STAFF_PHARMACIST'), isTrue);
      expect(NoAutomatedSubstitutionPolicy.isRoleAuthorized('PHARMACY_OWNER'), isTrue);
      expect(NoAutomatedSubstitutionPolicy.isRoleAuthorized('BRANCH_MANAGER'), isTrue);
      expect(NoAutomatedSubstitutionPolicy.isRoleAuthorized('CASHIER'), isFalse);
      expect(NoAutomatedSubstitutionPolicy.isRoleAuthorized('ACCOUNTANT'), isFalse);
      expect(NoAutomatedSubstitutionPolicy.isRoleAuthorized(null), isFalse);
    });

    test('Medicine substitution eligibility blocks narcotics and recalls', () {
      expect(
        NoAutomatedSubstitutionPolicy.isEligibleForSubstitution(
          isNarcotic: false,
          isRecalledOrBanned: false,
        ),
        isTrue,
      );

      // Narcotics forbidden
      expect(
        NoAutomatedSubstitutionPolicy.isEligibleForSubstitution(
          isNarcotic: true,
          isRecalledOrBanned: false,
        ),
        isFalse,
      );

      // Recalls forbidden
      expect(
        NoAutomatedSubstitutionPolicy.isEligibleForSubstitution(
          isNarcotic: false,
          isRecalledOrBanned: true,
        ),
        isFalse,
      );
    });

    test('Autonomous machine substitution strictly blocked', () {
      final res = NoAutomatedSubstitutionPolicy.validateManualSubstitution(
        originalProductId: 'prod-001',
        replacementProductId: 'prod-002',
        pharmacistPcbNo: 'PCB-12345',
        clinicalRationale: 'Out-of-stock brand replacement',
        isAutonomousMachineRequest: true,
      );
      expect(res.isValid, isFalse);
      expect(res.errorCode, 'ERR_AUTOMATED_SUBSTITUTION_FORBIDDEN');
      expect(res.errorMessage, contains('prohibited by law'));
    });

    test('Preflight validation enforces PCB, distinct products, and rationale length', () {
      final valid = NoAutomatedSubstitutionPolicy.validateManualSubstitution(
        originalProductId: 'prod-001',
        replacementProductId: 'prod-002',
        pharmacistPcbNo: 'PCB-99412',
        clinicalRationale: 'Exact 500mg generic equivalent verified with customer consent',
        isAutonomousMachineRequest: false,
      );
      expect(valid.isValid, isTrue);
      expect(valid.errorCode, isNull);

      // Short PCB
      final shortPcb = NoAutomatedSubstitutionPolicy.validateManualSubstitution(
        originalProductId: 'prod-001',
        replacementProductId: 'prod-002',
        pharmacistPcbNo: 'PCB',
        clinicalRationale: 'Generic equivalent',
        isAutonomousMachineRequest: false,
      );
      expect(shortPcb.isValid, isFalse);
      expect(shortPcb.errorCode, 'ERR_INVALID_PCB');

      // Short rationale
      final shortRationale = NoAutomatedSubstitutionPolicy.validateManualSubstitution(
        originalProductId: 'prod-001',
        replacementProductId: 'prod-002',
        pharmacistPcbNo: 'PCB-99412',
        clinicalRationale: 'swap',
        isAutonomousMachineRequest: false,
      );
      expect(shortRationale.isValid, isFalse);
      expect(shortRationale.errorCode, 'ERR_INVALID_RATIONALE');

      // Identical products
      final identical = NoAutomatedSubstitutionPolicy.validateManualSubstitution(
        originalProductId: 'prod-001',
        replacementProductId: 'prod-001',
        pharmacistPcbNo: 'PCB-99412',
        clinicalRationale: 'Swap same brand',
        isAutonomousMachineRequest: false,
      );
      expect(identical.isValid, isFalse);
      expect(identical.errorCode, 'ERR_IDENTICAL_PRODUCTS');
    });
  });
}

