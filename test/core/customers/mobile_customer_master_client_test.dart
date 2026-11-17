import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/customers/mobile_customer_master_client.dart';

void main() {
  group('P261: Mobile Customer Master Client Tests', () {
    test('enforces role authorization for credit limit and archiving', () {
      expect(MobileCustomerMasterClient.canManageCreditLimit('PHARMACY_OWNER'), isTrue);
      expect(MobileCustomerMasterClient.canManageCreditLimit('BRANCH_MANAGER'), isTrue);
      expect(MobileCustomerMasterClient.canManageCreditLimit('FINANCE_OFFICER'), isTrue);
      expect(MobileCustomerMasterClient.canManageCreditLimit('SUPERADMIN'), isTrue);

      expect(MobileCustomerMasterClient.canManageCreditLimit('CASHIER'), isFalse);
      expect(MobileCustomerMasterClient.canManageCreditLimit('STAFF_PHARMACIST'), isFalse);
      expect(MobileCustomerMasterClient.canManageCreditLimit(null), isFalse);

      expect(MobileCustomerMasterClient.canArchiveCustomer('PHARMACY_OWNER'), isTrue);
      expect(MobileCustomerMasterClient.canArchiveCustomer('CASHIER'), isFalse);
    });

    test('validates customer attributes correctly', () {
      expect(
        () => MobileCustomerMasterClient.validateCustomerData(
          fullName: 'Rahim Uddin',
          phone: '+8801712345678',
          creditLimitStr: '5000.00',
          creditTermsDays: 30,
        ),
        returnsNormally,
      );

      // Empty name
      expect(
        () => MobileCustomerMasterClient.validateCustomerData(
          fullName: '',
          phone: '+8801712345678',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Negative credit limit
      expect(
        () => MobileCustomerMasterClient.validateCustomerData(
          fullName: 'Rahim Uddin',
          creditLimitStr: '-100.00',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Terms days < 1
      expect(
        () => MobileCustomerMasterClient.validateCustomerData(
          fullName: 'Rahim Uddin',
          creditTermsDays: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Short phone
      expect(
        () => MobileCustomerMasterClient.validateCustomerData(
          fullName: 'Rahim Uddin',
          phone: '12345',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('provides sensible default privacy preferences', () {
      final prefs = MobileCustomerMasterClient.defaultPrivacyPreferences();
      expect(prefs['sms_receipts'], isTrue);
      expect(prefs['marketing_opt_in'], isFalse);
      expect(prefs['data_retention_consent'], isTrue);
    });

    test('formats bilingual customer summary displays', () {
      final summaryBn = MobileCustomerMasterClient.formatCustomerSummary(
        customerId: 'cust-101',
        fullName: 'Kamal Pasha',
        phone: '+8801811223344',
        creditStatus: 'APPROVED',
        currentDueBdt: '1250.00',
        lang: 'bn',
      );
      expect(summaryBn, contains('Kamal Pasha'));
      expect(summaryBn, contains('অনুমোদিত'));
      expect(summaryBn, contains('1250.00'));

      final summaryEn = MobileCustomerMasterClient.formatCustomerSummary(
        customerId: 'cust-101',
        fullName: 'Kamal Pasha',
        phone: null,
        creditStatus: 'UNAPPROVED',
        currentDueBdt: '0.00',
        lang: 'en',
      );
      expect(summaryEn, contains('No Phone'));
      expect(summaryEn, contains('Credit: Unapproved'));
    });
  });
}
