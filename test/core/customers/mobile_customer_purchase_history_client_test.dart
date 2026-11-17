import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/customers/mobile_customer_purchase_history_client.dart';

void main() {
  group('MobileCustomerPurchaseHistoryClient Tests', () {
    test('Builds valid history URI with default parameters', () {
      final uri = MobileCustomerPurchaseHistoryClient.buildHistoryUri(
        customerId: 'cust-12345',
      );
      expect(uri, contains('/api/v2/pos/customers/cust-12345/purchase-history/'));
      expect(uri, contains('page=1'));
      expect(uri, contains('page_size=20'));
      expect(uri, contains('event_type=ALL'));
    });

    test('Validates date formats and event types correctly', () {
      expect(
        () => MobileCustomerPurchaseHistoryClient.buildHistoryUri(
          customerId: 'cust-12345',
          startDate: '2026/11/17',
        ),
        throwsArgumentError,
      );

      expect(
        () => MobileCustomerPurchaseHistoryClient.buildHistoryUri(
          customerId: 'cust-12345',
          eventType: 'INVALID_TYPE',
        ),
        throwsArgumentError,
      );

      expect(
        () => MobileCustomerPurchaseHistoryClient.buildHistoryUri(
          customerId: 'cust-12345',
          page: 0,
        ),
        throwsArgumentError,
      );
    });

    test('Masks phone number for cashier and preserves for owner/pharmacist', () {
      const fullPhone = '+8801712345678';

      final maskedCashier = MobileCustomerPurchaseHistoryClient.maskPhoneNumber(
        fullPhone,
        role: 'CASHIER',
      );
      expect(maskedCashier, contains('*'));
      expect(maskedCashier.startsWith('+88017'), isTrue);
      expect(maskedCashier.endsWith('5678'), isTrue);

      final unmaskedOwner = MobileCustomerPurchaseHistoryClient.maskPhoneNumber(
        fullPhone,
        role: 'PHARMACY_OWNER',
      );
      expect(unmaskedOwner, equals(fullPhone));

      final unmaskedPharmacist = MobileCustomerPurchaseHistoryClient.maskPhoneNumber(
        fullPhone,
        role: 'STAFF_PHARMACIST',
      );
      expect(unmaskedPharmacist, equals(fullPhone));
    });

    test('Calculates net spend with non-negative lower bound', () {
      expect(MobileCustomerPurchaseHistoryClient.calculateNetSpend(1000.0, 200.0), equals(800.0));
      expect(MobileCustomerPurchaseHistoryClient.calculateNetSpend(100.0, 150.0), equals(0.0));
    });
  });
}
