import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/procurement/mobile_supplier_dashboard_client.dart';

void main() {
  group('MobileSupplierDashboardClient Tests (ADR-0199 / P199)', () {
    late Map<String, MobileSupplierDashboardSnapshot> snapshotStore;
    late MobileSupplierDashboardClient managerClient;
    late MobileSupplierDashboardClient cashierClient;

    setUp(() {
      snapshotStore = {};

      managerClient = MobileSupplierDashboardClient(
        tenantId: 'tenant-dhaka-001',
        branchId: 'branch-dhanmondi-01',
        userRole: 'BRANCH_MANAGER',
        userId: 'usr-mgr-1',
        snapshotStore: snapshotStore,
      );

      cashierClient = MobileSupplierDashboardClient(
        tenantId: 'tenant-dhaka-001',
        branchId: 'branch-dhanmondi-01',
        userRole: 'CASHIER',
        userId: 'usr-csh-1',
        snapshotStore: snapshotStore,
      );
    });

    List<MobileOpenOrderItem> createSampleOrders() {
      return [
        MobileOpenOrderItem(
          poId: 'po-101',
          poNumber: 'PO-202611-101',
          supplierName: 'Square Pharmaceuticals Ltd.',
          status: 'ORDERED',
          totalAmount: 15000.0,
        ),
        MobileOpenOrderItem(
          poId: 'po-102',
          poNumber: 'PO-202611-102',
          supplierName: 'Beximco Pharmaceuticals Ltd.',
          status: 'APPROVED',
          totalAmount: 8500.0,
        ),
      ];
    }

    List<MobileOverdueDeliveryItem> createSampleOverdue() {
      return [
        MobileOverdueDeliveryItem(
          poId: 'po-101',
          poNumber: 'PO-202611-101',
          supplierName: 'Square Pharmaceuticals Ltd.',
          expectedDeliveryDate: '2026-11-05',
          daysOverdue: 3,
          totalAmount: 15000.0,
        ),
      ];
    }

    List<MobileSupplierDueItem> createSampleDues() {
      return [
        MobileSupplierDueItem(
          supplierId: 'sup-sq',
          supplierName: 'Square Pharmaceuticals Ltd.',
          paymentTermsDays: 30,
          currentBalance: 45000.0,
          isOverdue: true,
        ),
        MobileSupplierDueItem(
          supplierId: 'sup-bx',
          supplierName: 'Beximco Pharmaceuticals Ltd.',
          paymentTermsDays: 45,
          currentBalance: 22000.0,
          isOverdue: false,
        ),
      ];
    }

    List<MobileLowStockSourcingItem> createSampleLowStock() {
      return [
        MobileLowStockSourcingItem(
          productId: 'prod-napa',
          brandName: 'Napa Extra 500mg',
          currentStock: 15,
          recommendedReorderQty: 100,
          preferredSupplierName: 'Square Pharmaceuticals Ltd.',
          quotedUnitCost: 2.50,
          estimatedCost: 250.0,
        ),
        MobileLowStockSourcingItem(
          productId: 'prod-seclo',
          brandName: 'Seclo 20mg',
          currentStock: 8,
          recommendedReorderQty: 80,
          preferredSupplierName: 'Square Pharmaceuticals Ltd.',
          quotedUnitCost: 5.00,
          estimatedCost: 400.0,
        ),
      ];
    }

    test('01. Compiles operations dashboard summary with open orders and overdue metrics', () {
      final summary = managerClient.compileSummary(
        orders: createSampleOrders(),
        overdue: createSampleOverdue(),
        dues: createSampleDues(),
        lowStock: createSampleLowStock(),
        activeSuppliersCount: 5,
      );

      expect(summary.openOrdersCount, equals(2));
      expect(summary.openOrdersValue, equals(23500.0));
      expect(summary.overdueDeliveriesCount, equals(1));
      expect(summary.overdueDeliveriesValue, equals(15000.0));
      expect(summary.totalDueBalance, equals(67000.0));
      expect(summary.lowStockOpportunitiesCount, equals(2));
      expect(summary.estimatedReorderCost, equals(650.0));
      expect(summary.activeSuppliersCount, equals(5));
    });

    test('02. Generates auditable dashboard snapshot with valid SHA-256 hash', () {
      final summary = managerClient.compileSummary(
        orders: createSampleOrders(),
        overdue: createSampleOverdue(),
        dues: createSampleDues(),
        lowStock: createSampleLowStock(),
        activeSuppliersCount: 5,
      );

      final snap = managerClient.createSnapshot(summary, 'Morning review');
      expect(snap.snapshotId.startsWith('sdash-'), isTrue);
      expect(snap.immutableVerificationHash.length, equals(64));
      expect(snap.notes, equals('Morning review'));
      expect(snap.generatedBy, equals('usr-mgr-1'));
    });

    test('03. Retrieves and lists historical snapshots', () {
      final summary = managerClient.compileSummary(
        orders: createSampleOrders(),
      );

      final snap1 = managerClient.createSnapshot(summary, 'Snap 1');
      final snap2 = managerClient.createSnapshot(summary, 'Snap 2');

      final retrieved = managerClient.getSnapshot(snap1.snapshotId);
      expect(retrieved.snapshotId, equals(snap1.snapshotId));
      expect(retrieved.immutableVerificationHash, equals(snap1.immutableVerificationHash));

      final list = managerClient.listSnapshots();
      expect(list.length, equals(2));
    });

    test('04. Cashier role access denied with ERR_STAFF_ROLE_DENIED', () {
      expect(
        () => cashierClient.compileSummary(),
        throwsA(predicate((e) =>
            e is Exception && e.toString().contains('ERR_STAFF_ROLE_DENIED'))),
      );
    });

    test('05. Handles empty operations data gracefully', () {
      final summary = managerClient.compileSummary();
      expect(summary.openOrdersCount, equals(0));
      expect(summary.openOrdersValue, equals(0.0));
      expect(summary.overdueDeliveriesCount, equals(0));
      expect(summary.totalDueBalance, equals(0.0));
      expect(summary.lowStockOpportunitiesCount, equals(0));
    });

    test('06. Verifies deterministic SHA-256 hash generation', () {
      final hash1 = MobileSupplierDashboardClient.computeVerificationHash(
        snapshotId: 'sdash-1',
        tenantId: 'tenant-1',
        openOrdersCount: 3,
        openOrdersValue: 1200.0,
        overdueDeliveriesCount: 1,
        totalDueBalance: 5000.0,
        lowStockCount: 2,
      );

      final hash2 = MobileSupplierDashboardClient.computeVerificationHash(
        snapshotId: 'sdash-1',
        tenantId: 'tenant-1',
        openOrdersCount: 3,
        openOrdersValue: 1200.0,
        overdueDeliveriesCount: 1,
        totalDueBalance: 5000.0,
        lowStockCount: 2,
      );

      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64));
    });
  });
}

