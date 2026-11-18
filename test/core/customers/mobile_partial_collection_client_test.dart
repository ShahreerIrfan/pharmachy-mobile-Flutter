import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/customers/mobile_partial_collection_client.dart';

void main() {
  group('MobilePartialCollectionClient Tests (P266)', () {
    test('calculateRemainingDue and isSettled compute exact values', () {
      final rem1 = MobilePartialCollectionClient.calculateRemainingDue(500.0, 200.0);
      expect(rem1, equals(300.0));
      expect(MobilePartialCollectionClient.isSettled(500.0, 200.0), isFalse);

      final rem2 = MobilePartialCollectionClient.calculateRemainingDue(300.0, 300.0);
      expect(rem2, equals(0.0));
      expect(MobilePartialCollectionClient.isSettled(300.0, 300.0), isTrue);
    });

    test('validatePartialCollection passes for valid cash and digital collections', () {
      expect(
        () => MobilePartialCollectionClient.validatePartialCollection(
          amount: 250.0,
          remainingDue: 500.0,
          tenderType: 'CASH',
        ),
        returnsNormally,
      );

      expect(
        () => MobilePartialCollectionClient.validatePartialCollection(
          amount: 150.0,
          remainingDue: 200.0,
          tenderType: 'BKASH',
          gatewayRef: 'TRX998811',
        ),
        returnsNormally,
      );
    });

    test('validatePartialCollection rejects overpayments, zero amounts, and settled invoices', () {
      // Overpayment
      expect(
        () => MobilePartialCollectionClient.validatePartialCollection(
          amount: 600.0,
          remainingDue: 500.0,
          tenderType: 'CASH',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Zero amount
      expect(
        () => MobilePartialCollectionClient.validatePartialCollection(
          amount: 0.0,
          remainingDue: 500.0,
          tenderType: 'CASH',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Already settled
      expect(
        () => MobilePartialCollectionClient.validatePartialCollection(
          amount: 100.0,
          remainingDue: 0.0,
          tenderType: 'CASH',
        ),
        throwsA(isA<StateError>()),
      );

      // Missing digital gateway ref
      expect(
        () => MobilePartialCollectionClient.validatePartialCollection(
          amount: 100.0,
          remainingDue: 300.0,
          tenderType: 'NAGAD',
          gatewayRef: '12',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('canReverseCollection enforces privileged role check', () {
      expect(MobilePartialCollectionClient.canReverseCollection('PHARMACY_OWNER'), isTrue);
      expect(MobilePartialCollectionClient.canReverseCollection('BRANCH_MANAGER'), isTrue);
      expect(MobilePartialCollectionClient.canReverseCollection('CASHIER'), isFalse);
      expect(MobilePartialCollectionClient.canReverseCollection('DISPENSER'), isFalse);
      expect(MobilePartialCollectionClient.canReverseCollection(null), isFalse);
    });
  });
}
