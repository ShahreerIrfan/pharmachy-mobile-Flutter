// mobile_payment_method_registry_client_test.dart
// Architecture Decision: ADR-0275 (P275).
// Phase 14: Customers, Suppliers, Dues & Payments.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/finance/mobile_payment_method_registry_client.dart';

void main() {
  group('MobilePaymentMethodRegistryClient Tests (P275)', () {
    const tenantId = 'ten-dhk-01';
    const branchId = 'br-dhanmondi-01';

    late MobilePaymentMethodRegistryClient managerClient;
    late MobilePaymentMethodRegistryClient cashierClient;
    late Map<String, MobilePaymentMethodConfigDto> sharedStore;

    setUp(() {
      sharedStore = {};
      managerClient = MobilePaymentMethodRegistryClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'BRANCH_MANAGER',
        userId: 'mgr_01',
        configStore: sharedStore,
      );

      cashierClient = MobilePaymentMethodRegistryClient(
        tenantId: tenantId,
        branchId: branchId,
        userRole: 'CASHIER',
        userId: 'csh_01',
        configStore: sharedStore,
      );
    });

    test('1. Successful configuration of Cash and bKash payment methods', () {
      final cash = managerClient.configurePaymentMethod(
        methodType: 'CASH',
        displayName: 'Cash at Counter',
        displayOrder: 1,
        allowOffline: true,
      );

      expect(cash.methodType, equals('CASH'));
      expect(cash.allowOffline, isTrue);

      final bkash = managerClient.configurePaymentMethod(
        methodType: 'BKASH',
        displayName: 'bKash Merchant Pay',
        displayOrder: 2,
        requiresReference: true,
        referenceLabel: 'TrxID',
        referencePattern: r'^[A-Z0-9]{8,12}$',
        customerSurchargePercentage: 1.5,
        minTransactionBdt: 10.0,
        maxTransactionBdt: 25000.0,
        allowOffline: false,
      );

      expect(bkash.methodType, equals('BKASH'));
      expect(bkash.requiresReference, isTrue);
      expect(bkash.customerSurchargePercentage, equals(1.5));
    });

    test('2. Zero Secrets Guard: Rejects plain sensitive credentials', () {
      expect(
        () => managerClient.configurePaymentMethod(
          methodType: 'CARD',
          displayName: 'Card Terminal',
          optionalSecretsCheck: {'secret_key': 'super_secret_api_key_123'},
        ),
        throwsA(isA<PaymentMethodValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_SENSITIVE_SECRET_EXPOSURE_BLOCKED'),
        )),
      );
    });

    test('3. Role enforcement: Cashier is denied configuring payment methods', () {
      expect(
        () => cashierClient.configurePaymentMethod(
          methodType: 'NAGAD',
          displayName: 'Nagad Pay',
        ),
        throwsA(isA<PaymentMethodPermissionException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_STAFF_ROLE_DENIED'),
        )),
      );
    });

    test('4. Tender validation: Reference check, surcharge and limits', () {
      final bkash = managerClient.configurePaymentMethod(
        methodType: 'BKASH',
        displayName: 'bKash Pay',
        requiresReference: true,
        referenceLabel: 'TrxID',
        referencePattern: r'^[A-Z0-9]{10}$',
        customerSurchargePercentage: 2.0,
        minTransactionBdt: 50.0,
        maxTransactionBdt: 10000.0,
        allowOffline: false,
      );

      // Valid tender
      final validRes = cashierClient.validateTender(
        configId: bkash.configId,
        amountBdt: 1000.0,
        reference: 'BK99887766',
        isOffline: false,
      );

      expect(validRes['is_valid'], isTrue);
      expect(validRes['surcharge_bdt'], equals(20.0));
      expect(validRes['total_payable_bdt'], equals(1020.0));

      // Invalid reference pattern (only 5 chars instead of 10)
      expect(
        () => cashierClient.validateTender(
          configId: bkash.configId,
          amountBdt: 500.0,
          reference: 'SHORT',
        ),
        throwsA(isA<PaymentMethodValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_INVALID_REFERENCE_FORMAT'),
        )),
      );

      // Amount below min limit
      expect(
        () => cashierClient.validateTender(
          configId: bkash.configId,
          amountBdt: 20.0,
          reference: 'BK99887766',
        ),
        throwsA(isA<PaymentMethodValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_TRANSACTION_AMOUNT_OUT_OF_BOUNDS'),
        )),
      );
    });

    test('5. Offline payment protection: Rejects non-offline payment methods offline', () {
      final card = managerClient.configurePaymentMethod(
        methodType: 'CARD',
        displayName: 'POS Card Terminal',
        allowOffline: false,
      );

      expect(
        () => cashierClient.validateTender(
          configId: card.configId,
          amountBdt: 500.0,
          isOffline: true,
        ),
        throwsA(isA<PaymentMethodValidationException>().having(
          (e) => e.errorCode,
          'errorCode',
          equals('ERR_OFFLINE_PAYMENT_NOT_ALLOWED'),
        )),
      );
    });
  });
}
