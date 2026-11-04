import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_stock_availability_client.dart';

void main() {
  group('P171 MobileStockAvailabilityClient Tests', () {
    test('Test 1: Stock conservation and availability invariants', () {
      final rec = MobileStockAvailabilityRecord(
        availabilityId: 'bav-m1',
        tenantId: 'tenant-dhanmondi',
        branchId: 'branch-main',
        productId: 'prod-ace-500',
        productName: 'Ace 500mg',
        genericName: 'Paracetamol',
        baseUnit: 'TABLET',
        quantityOnHand: 150,
        quantityReserved: 30,
        quantityQuarantined: 20,
        quantityPendingInward: 100,
        reorderLevelBaseUnits: 50,
      );

      // physically_available = on_hand - quarantined = 150 - 20 = 130
      expect(rec.quantityPhysicallyAvailable, equals(130));

      // server_confirmed_available = physically_available - reserved = 130 - 30 = 100
      expect(rec.quantityServerConfirmedAvailable, equals(100));

      // Stock conservation
      expect(
        rec.quantityOnHand,
        equals(rec.quantityServerConfirmedAvailable + rec.quantityReserved + rec.quantityQuarantined),
      );

      expect(rec.isOutOfStock, isFalse);
      expect(rec.isBelowReorderLevel, isFalse); // 100 > 50
    });

    test('Test 2: Multi-level packaging breakdown format', () {
      final str100 = MobileStockAvailabilityClient.formatPackaging(
        baseUnit: 'TABLET',
        packLabel: 'BOX',
        interLabel: 'STRIP',
        packToInter: 10,
        interToBase: 10,
        totalBaseUnits: 100,
      );
      expect(str100, contains('1 BOX'));

      final str25 = MobileStockAvailabilityClient.formatPackaging(
        baseUnit: 'TABLET',
        packLabel: 'BOX',
        interLabel: 'STRIP',
        packToInter: 10,
        interToBase: 10,
        totalBaseUnits: 25,
      );
      expect(str25, contains('2 STRIPs'));
      expect(str25, contains('5 TABLETs'));

      final strZero = MobileStockAvailabilityClient.formatPackaging(
        baseUnit: 'TABLET',
        totalBaseUnits: 0,
      );
      expect(strZero, equals('0 TABLET'));
    });

    test('Test 3: POS Cart precheck with available items and shortage detection', () {
      final client = MobileStockAvailabilityClient(
        tenantId: 'tenant-dhanmondi',
        branchId: 'branch-main',
        userRole: 'CASHIER',
      );

      client.putRecord(MobileStockAvailabilityRecord(
        availabilityId: 'bav-1',
        tenantId: 'tenant-dhanmondi',
        branchId: 'branch-main',
        productId: 'prod-1',
        quantityOnHand: 80,
        quantityReserved: 10,
        quantityQuarantined: 0, // server confirmed = 70
      ));

      client.putRecord(MobileStockAvailabilityRecord(
        availabilityId: 'bav-2',
        tenantId: 'tenant-dhanmondi',
        branchId: 'branch-main',
        productId: 'prod-2',
        quantityOnHand: 15,
        quantityReserved: 0,
        quantityQuarantined: 5, // server confirmed = 10
      ));

      // Request 50 of prod-1 (Available), 25 of prod-2 (Shortage 15)
      final res = client.precheckCheckout([
        MobilePrecheckItemRequest(productId: 'prod-1', requestedQuantityBaseUnits: 50),
        MobilePrecheckItemRequest(productId: 'prod-2', requestedQuantityBaseUnits: 25),
      ]);

      expect(res.success, isTrue);
      final data = res.data!;
      expect(data.allItemsAvailable, isFalse);

      expect(data.items[0].isAvailable, isTrue);
      expect(data.items[0].shortageUnits, equals(0));

      expect(data.items[1].isAvailable, isFalse);
      expect(data.items[1].shortageUnits, equals(15));
    });

    test('Test 4: Role authorization and suspended tenant blocking', () {
      final unauthClient = MobileStockAvailabilityClient(
        tenantId: 'tenant-dhanmondi',
        branchId: 'branch-main',
        userRole: 'VISITOR',
      );
      final unauthRes = unauthClient.getAvailability('prod-1');
      expect(unauthRes.success, isFalse);
      expect(unauthRes.errorCode, equals('ERR_ROLE_UNAUTHORIZED'));

      final suspendedClient = MobileStockAvailabilityClient(
        tenantId: 'tenant-dhanmondi',
        branchId: 'branch-main',
        userRole: 'CASHIER',
        isTenantSuspended: true,
      );
      final suspRes = suspendedClient.getAvailability('prod-1');
      expect(suspRes.success, isFalse);
      expect(suspRes.errorCode, equals('ERR_TENANT_SUSPENDED'));
    });
  });
}
