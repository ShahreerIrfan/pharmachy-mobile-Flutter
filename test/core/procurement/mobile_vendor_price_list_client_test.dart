// mobile_vendor_price_list_client_test.dart
// Architecture Decision: ADR-0183 (P183).
// Phase 10: Suppliers, Purchase Orders & Supply Chain.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_vendor_price_list_client.dart';

void main() {
  group('MobileVendorPriceListClient Tests (P183)', () {
    late MobileVendorPriceListClient managerClient;
    late MobileVendorPriceListClient cashierClient;
    late MobileVendorPriceListClient foreignClient;

    setUp(() {
      final sharedStore = <String, MobileVendorProductPriceList>{};

      managerClient = MobileVendorPriceListClient(
        tenantId: 'tenant-evercare',
        branchId: 'branch-1',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-1',
        initialStore: sharedStore,
      );

      cashierClient = MobileVendorPriceListClient(
        tenantId: 'tenant-evercare',
        branchId: 'branch-1',
        userRole: 'CASHIER',
        userId: 'usr-csh-1',
        initialStore: sharedStore,
      );

      foreignClient = MobileVendorPriceListClient(
        tenantId: 'tenant-other',
        branchId: 'branch-2',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-2',
        initialStore: sharedStore,
      );
    });

    test(
        'Test 1: Valid price entry creation with trade discount and net unit cost calculation',
        () {
      final entry = managerClient.createPriceEntry(
        supplierId: 'sup-square-001',
        supplierName: 'Square Pharmaceuticals Depot',
        productId: 'prod-napa-500',
        productName: 'Napa 500mg Tablet',
        supplierSkuCode: 'SQ-NAP-500',
        packageType: 'BOX',
        packageSize: 100,
        unitCostPrice: 8.50,
        mrpUnit: 10.00,
        discountPercentage: 10.00, // 10% discount -> net 7.65
        effectiveFrom: DateTime(2026, 1, 1),
        effectiveTo: DateTime(2026, 12, 31),
        minimumOrderQuantity: 50,
        freeGoodsThreshold: 100,
        freeGoodsBonusQuantity: 5,
        isContracted: true,
        notes: 'Annual rate contract',
      );

      expect(entry.priceEntryId, startsWith('vpl-'));
      expect(entry.tenantId, equals('tenant-evercare'));
      expect(entry.unitCostPrice, equals(8.50));
      expect(entry.packageCostPrice, equals(850.00));
      expect(entry.mrpUnit, equals(10.00));
      expect(entry.discountPercentage, equals(10.00));
      expect(entry.netUnitCost, equals(7.65));
      expect(entry.isActive, isTrue);

      // Retrieval and list
      final fetched = managerClient.getPriceEntry(entry.priceEntryId);
      expect(fetched.priceEntryId, equals(entry.priceEntryId));

      final list = managerClient.listPriceEntries(
        supplierId: 'sup-square-001',
        productId: 'prod-napa-500',
        activeOnDate: DateTime(2026, 6, 1),
        isActive: true,
      );
      expect(list.length, equals(1));
      expect(list.first.priceEntryId, equals(entry.priceEntryId));
    });

    test('Test 2: DGDA MRP ceiling guard and parameter bounds enforcement', () {
      // Unit cost exceeds MRP
      expect(
        () => managerClient.createPriceEntry(
          supplierId: 'sup-square-001',
          productId: 'prod-napa-500',
          unitCostPrice: 12.50, // Exceeds MRP
          mrpUnit: 10.00,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Negative unit cost
      expect(
        () => managerClient.createPriceEntry(
          supplierId: 'sup-square-001',
          productId: 'prod-napa-500',
          unitCostPrice: -5.00,
          mrpUnit: 10.00,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Discount > 100%
      expect(
        () => managerClient.createPriceEntry(
          supplierId: 'sup-square-001',
          productId: 'prod-napa-500',
          unitCostPrice: 8.00,
          mrpUnit: 10.00,
          discountPercentage: 110.0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // MOQ < 1
      expect(
        () => managerClient.createPriceEntry(
          supplierId: 'sup-square-001',
          productId: 'prod-napa-500',
          unitCostPrice: 8.00,
          mrpUnit: 10.00,
          minimumOrderQuantity: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Effective to before effective from
      expect(
        () => managerClient.createPriceEntry(
          supplierId: 'sup-square-001',
          productId: 'prod-napa-500',
          unitCostPrice: 8.00,
          mrpUnit: 10.00,
          effectiveFrom: DateTime(2026, 6, 1),
          effectiveTo: DateTime(2026, 5, 1),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
        'Test 3: Best-price PO resolution with MOQ thresholding and bonus free goods calculation',
        () {
      // Supplier A: net cost = 8.50 * 0.95 = 8.0750, MOQ = 50, bonus: 100 -> 5
      managerClient.createPriceEntry(
        supplierId: 'sup-A',
        supplierName: 'Supplier A',
        productId: 'prod-ace-500',
        productName: 'Ace 500',
        unitCostPrice: 8.50,
        mrpUnit: 10.00,
        discountPercentage: 5.0,
        effectiveFrom: DateTime(2026, 1, 1),
        effectiveTo: DateTime(2026, 12, 31),
        minimumOrderQuantity: 50,
        freeGoodsThreshold: 100,
        freeGoodsBonusQuantity: 5,
      );

      // Supplier B: net cost = 8.20 * 0.90 = 7.3800, MOQ = 200, no bonus
      managerClient.createPriceEntry(
        supplierId: 'sup-B',
        supplierName: 'Supplier B',
        productId: 'prod-ace-500',
        productName: 'Ace 500',
        unitCostPrice: 8.20,
        mrpUnit: 10.00,
        discountPercentage: 10.0,
        effectiveFrom: DateTime(2026, 1, 1),
        effectiveTo: DateTime(2026, 12, 31),
        minimumOrderQuantity: 200,
      );

      // Order 100 units: Supplier B MOQ (200) not met. Supplier A is selected.
      final offer100 = managerClient.resolveBestPrice(
        productId: 'prod-ace-500',
        demandedQuantity: 100,
        targetDate: DateTime(2026, 6, 1),
      );
      expect(offer100, isNotNull);
      expect(offer100!.supplierId, equals('sup-A'));
      expect(offer100.netUnitCost, equals(8.075));
      expect(offer100.totalNetCost, equals(807.5));
      expect(offer100.freeGoodsBonusUnits, equals(5));

      // Order 250 units: Supplier B satisfies MOQ (200) and is cheaper (7.38 < 8.075). Supplier B wins.
      final offer250 = managerClient.resolveBestPrice(
        productId: 'prod-ace-500',
        demandedQuantity: 250,
        targetDate: DateTime(2026, 6, 1),
      );
      expect(offer250, isNotNull);
      expect(offer250!.supplierId, equals('sup-B'));
      expect(offer250.netUnitCost, equals(7.38));
      expect(offer250.totalNetCost, equals(1845.0));
      expect(offer250.freeGoodsBonusUnits, equals(0));
    });

    test('Test 4: RBAC enforcement and cross-tenant isolation guarantees', () {
      // Cashier cannot create price entry
      expect(
        () => cashierClient.createPriceEntry(
          supplierId: 'sup-square-001',
          productId: 'prod-napa-500',
          unitCostPrice: 8.00,
          mrpUnit: 10.00,
        ),
        throwsA(isA<StateError>()),
      );

      // Manager creates price entry
      final entry = managerClient.createPriceEntry(
        supplierId: 'sup-square-001',
        productId: 'prod-napa-500',
        unitCostPrice: 8.00,
        mrpUnit: 10.00,
      );

      // Cashier cannot update or archive
      expect(
        () => cashierClient.updatePriceEntry(
          priceEntryId: entry.priceEntryId,
          newUnitCostPrice: 7.50,
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        () => cashierClient.archivePriceEntry(entry.priceEntryId),
        throwsA(isA<StateError>()),
      );

      // Cross-tenant access forbidden
      expect(
        () => foreignClient.getPriceEntry(entry.priceEntryId),
        throwsA(isA<StateError>()),
      );
      expect(
        () => foreignClient.updatePriceEntry(
          priceEntryId: entry.priceEntryId,
          newUnitCostPrice: 7.50,
        ),
        throwsA(isA<StateError>()),
      );

      // Soft archive by manager
      final archived = managerClient.archivePriceEntry(entry.priceEntryId);
      expect(archived.isActive, isFalse);
    });
  });
}

