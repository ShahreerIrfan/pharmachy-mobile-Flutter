import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/prescriptions/mobile_drug_license_client.dart';

void main() {
  group('MobileDrugLicenseClient Tests (P251)', () {
    test('Role authorization checks', () {
      expect(MobileDrugLicenseClient.isRoleAuthorizedToManage('SUPERADMIN'), isTrue);
      expect(MobileDrugLicenseClient.isRoleAuthorizedToManage('PHARMACY_OWNER'), isTrue);
      expect(MobileDrugLicenseClient.isRoleAuthorizedToManage('BRANCH_MANAGER'), isTrue);
      expect(MobileDrugLicenseClient.isRoleAuthorizedToManage('STAFF_PHARMACIST'), isFalse);
      expect(MobileDrugLicenseClient.isRoleAuthorizedToManage('CASHIER'), isFalse);
      expect(MobileDrugLicenseClient.isRoleAuthorizedToManage(null), isFalse);
    });

    test('License evaluation states (active, expiring soon, expired, renewal pending, suspended)', () {
      // Active and healthy
      final healthy = MobileDrugLicenseClient.evaluateLicense(
        status: DrugLicenseStatus.active,
        daysUntilExpiry: 180,
      );
      expect(healthy.isValid, isTrue);
      expect(healthy.statusCode, 'ACTIVE');

      // Expiring soon (<=30 days)
      final expiring = MobileDrugLicenseClient.evaluateLicense(
        status: DrugLicenseStatus.active,
        daysUntilExpiry: 20,
      );
      expect(expiring.isValid, isTrue);
      expect(expiring.statusCode, 'EXPIRING_SOON');
      expect(expiring.messageEn, contains('20 days'));
      expect(expiring.messageBn, contains('20 দিন'));

      // Expired without renewal
      final expired = MobileDrugLicenseClient.evaluateLicense(
        status: DrugLicenseStatus.expired,
        daysUntilExpiry: -1,
      );
      expect(expired.isValid, isFalse);
      expect(expired.statusCode, 'EXPIRED');

      // Expired with renewal submitted
      final renewal = MobileDrugLicenseClient.evaluateLicense(
        status: DrugLicenseStatus.renewalPending,
        daysUntilExpiry: -15,
      );
      expect(renewal.isValid, isTrue);
      expect(renewal.statusCode, 'RENEWAL_PENDING');

      // Suspended
      final suspended = MobileDrugLicenseClient.evaluateLicense(
        status: DrugLicenseStatus.suspended,
        daysUntilExpiry: 60,
      );
      expect(suspended.isValid, isFalse);
      expect(suspended.statusCode, 'SUSPENDED');
    });

    test('Preflight validation checks required lengths and date ordering', () {
      expect(
        MobileDrugLicenseClient.validatePreflight(
          licenseNumber: 'DL-DHK-2024-99812',
          issuingAuthority: 'DGDA Dhaka',
          issueDateStr: '2024-01-01',
          expiryDateStr: '2026-12-31',
        ),
        isTrue,
      );

      // Short license number
      expect(
        MobileDrugLicenseClient.validatePreflight(
          licenseNumber: 'DL',
          issuingAuthority: 'DGDA',
          issueDateStr: '2024-01-01',
          expiryDateStr: '2026-12-31',
        ),
        isFalse,
      );

      // Inverted dates
      expect(
        MobileDrugLicenseClient.validatePreflight(
          licenseNumber: 'DL-DHK-2024-99812',
          issuingAuthority: 'DGDA',
          issueDateStr: '2026-12-31',
          expiryDateStr: '2024-01-01',
        ),
        isFalse,
      );
    });

    test('License type localization', () {
      expect(DrugLicenseType.form20Retail.getLocalizedLabel('bn'), contains('ফরম ২০'));
      expect(DrugLicenseType.form20Retail.getLocalizedLabel('en'), contains('Form 20'));
    });
  });
}
