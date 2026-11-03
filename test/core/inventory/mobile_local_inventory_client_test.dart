import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_local_inventory_client.dart';

void main() {
  group('MobileLocalInventoryClient Tests (P156)', () {
    late MobileLocalInventoryClient client;

    setUp(() {
      client = MobileLocalInventoryClient();
    });

    test('P156-MOB-01: Valid local inventory parameters succeed with custom selling price', () {
      final result = client.validateLocalInventory(
        localSku: 'SKU-DHK-01',
        localSellingPriceBdt: 2.45,
        masterMrpUnit: 2.50,
        reorderLevel: 15,
        minOrderQuantity: 5,
        maxCapacityUnits: 500,
        shelfLocation: 'Rack-A2 / Shelf-3',
      );

      expect(result.isValid, isTrue);
      expect(result.errorCode, isNull);
      expect(result.effectiveSellingPrice, 2.45);
      expect(result.isPriceOverridden, isTrue);
    });

    test('P156-MOB-02: Missing local price falls back to master MRP unit', () {
      final result = client.validateLocalInventory(
        localSku: 'SKU-DHK-02',
        masterMrpUnit: 2.50,
        reorderLevel: 10,
      );

      expect(result.isValid, isTrue);
      expect(result.effectiveSellingPrice, 2.50);
      expect(result.isPriceOverridden, isFalse);
    });

    test('P156-MOB-03: Invalid local SKU format triggers ERR_INVALID_SKU_FORMAT', () {
      final result = client.validateLocalInventory(
        localSku: 'SKU#BAD@CHARS!',
      );

      expect(result.isValid, isFalse);
      expect(result.errorCode, 'ERR_INVALID_SKU_FORMAT');
    });

    test('P156-MOB-04: Selling price below 0.01 triggers ERR_INVALID_SELLING_PRICE', () {
      final result = client.validateLocalInventory(
        localSellingPriceBdt: 0.00,
      );

      expect(result.isValid, isFalse);
      expect(result.errorCode, 'ERR_INVALID_SELLING_PRICE');
    });

    test('P156-MOB-05: Negative reorder level triggers ERR_INVALID_REORDER_LEVEL', () {
      final result = client.validateLocalInventory(
        reorderLevel: -5,
      );

      expect(result.isValid, isFalse);
      expect(result.errorCode, 'ERR_INVALID_REORDER_LEVEL');
    });

    test('P156-MOB-06: Max capacity below min order quantity triggers ERR_CAPACITY_BELOW_MIN_ORDER', () {
      final result = client.validateLocalInventory(
        minOrderQuantity: 50,
        maxCapacityUnits: 20,
      );

      expect(result.isValid, isFalse);
      expect(result.errorCode, 'ERR_CAPACITY_BELOW_MIN_ORDER');
    });

    test('P156-MOB-07: Low stock detection correctly evaluates threshold', () {
      expect(client.isLowStock(10, 15), isTrue);
      expect(client.isLowStock(15, 15), isTrue);
      expect(client.isLowStock(20, 15), isFalse);
    });

    test('P156-MOB-08: Cashier role is restricted from mutating inventory overrides', () {
      expect(client.canMutateInventory('STAFF_PHARMACIST'), isTrue);
      expect(client.canMutateInventory('PHARMACY_OWNER'), isTrue);
      expect(client.canMutateInventory('SUPERADMIN'), isTrue);
      expect(client.canMutateInventory('CASHIER'), isFalse);
      expect(client.canMutateInventory(null), isFalse);
    });

    test('P156-MOB-09: Build inventory payload produces canonical format', () {
      final payload = client.buildInventoryPayload(
        productId: 'prod-tab-01',
        branchId: 'br-dhk-01',
        localSku: 'SKU-LOC-01',
        localSellingPriceBdt: 2.45,
        reorderLevel: 20,
        shelfLocation: 'Rack-B2 / Shelf-1',
        isVisible: true,
      );

      expect(payload['product_id'], 'prod-tab-01');
      expect(payload['branch_id'], 'br-dhk-01');
      expect(payload['local_sku'], 'SKU-LOC-01');
      expect(payload['local_selling_price_bdt'], 2.45);
      expect(payload['reorder_level'], 20);
      expect(payload['shelf_location'], 'Rack-B2 / Shelf-1');
      expect(payload['is_visible'], isTrue);
    });
  });
}
