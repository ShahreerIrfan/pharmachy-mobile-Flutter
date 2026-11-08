import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_stock_inquiry_client.dart';

void main() {
  group('MobileStockInquiryClient Tests (ADR-0203 / P203)', () {
    late MobileStockInquiryClient client;
    const tenantA = 'ten-dhaka-01';
    const branchA1 = 'br-main';
    const branchA2 = 'br-mirpur';
    const tenantB = 'ten-chittagong-02';

    setUp(() {
      client = MobileStockInquiryClient();
    });

    test('1. Product stock rollup, available math, packaging breakdown and FEFO order', () {
      final today = DateTime.now();

      // Batch 1: Active 100 units, 20 reserved -> 80 available
      client.addBatch(MobileMockBatchRecord(
        batchId: 'bat-01',
        tenantId: tenantA,
        branchId: branchA1,
        productId: 'prod-napa-500',
        brandName: 'Napa 500mg',
        brandNameBn: 'নাপা ৫০০',
        genericName: 'Paracetamol',
        dosageForm: 'TABLET',
        batchNumber: 'BAT-ACT-01',
        quantity: 100,
        reserved: 20,
        expiryDate: today.add(const Duration(days: 200)),
        isQuarantined: false,
        isRecalled: false,
        costPerUnit: 1.20,
        mrpUnit: 1.50,
        storageLocation: 'SH-A1',
      ));

      // Batch 2: Near expiry 40 units
      client.addBatch(MobileMockBatchRecord(
        batchId: 'bat-02',
        tenantId: tenantA,
        branchId: branchA1,
        productId: 'prod-napa-500',
        brandName: 'Napa 500mg',
        brandNameBn: 'নাপা ৫০০',
        genericName: 'Paracetamol',
        dosageForm: 'TABLET',
        batchNumber: 'BAT-NEAR-02',
        quantity: 40,
        reserved: 0,
        expiryDate: today.add(const Duration(days: 45)),
        isQuarantined: false,
        isRecalled: false,
        costPerUnit: 1.20,
        mrpUnit: 1.50,
        storageLocation: 'SH-A2',
      ));

      // Batch 3: Expired 30 units
      client.addBatch(MobileMockBatchRecord(
        batchId: 'bat-03',
        tenantId: tenantA,
        branchId: branchA1,
        productId: 'prod-napa-500',
        brandName: 'Napa 500mg',
        brandNameBn: 'নাপা ৫০০',
        genericName: 'Paracetamol',
        dosageForm: 'TABLET',
        batchNumber: 'BAT-EXP-03',
        quantity: 30,
        reserved: 0,
        expiryDate: today.subtract(const Duration(days: 5)),
        isQuarantined: false,
        isRecalled: false,
        costPerUnit: 1.20,
        mrpUnit: 1.50,
        storageLocation: 'SH-DISP',
      ));

      // Batch 4: Quarantined 25 units
      client.addBatch(MobileMockBatchRecord(
        batchId: 'bat-04',
        tenantId: tenantA,
        branchId: branchA1,
        productId: 'prod-napa-500',
        brandName: 'Napa 500mg',
        brandNameBn: 'নাপা ৫০০',
        genericName: 'Paracetamol',
        dosageForm: 'TABLET',
        batchNumber: 'BAT-QUAR-04',
        quantity: 25,
        reserved: 0,
        expiryDate: today.add(const Duration(days: 150)),
        isQuarantined: true,
        isRecalled: false,
        costPerUnit: 1.20,
        mrpUnit: 1.50,
        storageLocation: 'QUAR-Z1',
      ));

      final res = client.queryStock(
        tenantId: tenantA,
        branchId: branchA1,
        productId: 'prod-napa-500',
        userRole: 'BRANCH_MANAGER',
        userBranchId: branchA1,
      );

      expect(res.productsCount, equals(1));
      final prod = res.results.first;

      // Invariants:
      expect(prod.totalQuantityBaseUnits, equals(195));
      expect(prod.availableQuantityBaseUnits, equals(120));
      expect(prod.reservedQuantityBaseUnits, equals(20));
      expect(prod.expiredQuantityBaseUnits, equals(30));
      expect(prod.quarantinedQuantityBaseUnits, equals(25));
      expect(prod.nearExpiryQuantityBaseUnits, equals(40));

      // Packaging breakdown
      expect(prod.packagingSummary.boxes, equals(1));
      expect(prod.packagingSummary.strips, equals(2));
      expect(prod.packagingSummary.pieces, equals(0));

      // FEFO ordering: Expired first, then Near-Expiry
      expect(prod.batches.length, equals(4));
      expect(prod.batches[0].batchNumber, equals('BAT-EXP-03'));
      expect(prod.batches[1].batchNumber, equals('BAT-NEAR-02'));
    });

    test('2. Valuation calculation precision', () {
      final today = DateTime.now();
      client.addBatch(MobileMockBatchRecord(
        batchId: 'b-val',
        tenantId: tenantA,
        branchId: branchA1,
        productId: 'p-val',
        brandName: 'Test Med',
        brandNameBn: 'টেস্ট মেডিসিন',
        genericName: 'Test Molecule',
        dosageForm: 'TABLET',
        batchNumber: 'BV1',
        quantity: 200,
        reserved: 0,
        expiryDate: today.add(const Duration(days: 100)),
        isQuarantined: false,
        isRecalled: false,
        costPerUnit: 1.25,
        mrpUnit: 1.50,
        storageLocation: 'SH-01',
      ));

      final res = client.queryStock(
        tenantId: tenantA,
        branchId: branchA1,
        userRole: 'PHARMACY_OWNER',
        userBranchId: branchA1,
      );

      final prod = res.results.first;
      expect(prod.totalCostValuationBdt, closeTo(250.0, 0.001));
      expect(prod.totalMrpValuationBdt, closeTo(300.0, 0.001));
    });

    test('3. Cashier branch restriction', () {
      expect(
        () => client.queryStock(
          tenantId: tenantA,
          branchId: branchA2,
          userRole: 'CASHIER',
          userBranchId: branchA1,
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_BRANCH_ACCESS_DENIED'),
        )),
      );
    });

    test('4. Cross-tenant isolation', () {
      final today = DateTime.now();
      client.addBatch(MobileMockBatchRecord(
        batchId: 'b-iso',
        tenantId: tenantA,
        branchId: branchA1,
        productId: 'p-iso',
        brandName: 'Iso Med',
        brandNameBn: 'আইসো',
        genericName: 'Iso Molecule',
        dosageForm: 'TABLET',
        batchNumber: 'BISO1',
        quantity: 50,
        reserved: 0,
        expiryDate: today.add(const Duration(days: 100)),
        isQuarantined: false,
        isRecalled: false,
        costPerUnit: 1.0,
        mrpUnit: 1.2,
        storageLocation: 'SH-01',
      ));

      final res = client.queryStock(
        tenantId: tenantB,
        branchId: branchA1,
        userRole: 'BRANCH_MANAGER',
        userBranchId: branchA1,
      );
      expect(res.productsCount, equals(0));
    });

    test('5. Bangla keyword search and expiry filtering', () {
      final today = DateTime.now();
      client.addBatch(MobileMockBatchRecord(
        batchId: 'b-01',
        tenantId: tenantA,
        branchId: branchA1,
        productId: 'p-1',
        brandName: 'Napa Extra',
        brandNameBn: 'নাপা এক্সট্রা',
        genericName: 'Paracetamol',
        dosageForm: 'TABLET',
        batchNumber: 'B1',
        quantity: 40,
        reserved: 0,
        expiryDate: today.add(const Duration(days: 120)),
        isQuarantined: false,
        isRecalled: false,
        costPerUnit: 2.0,
        mrpUnit: 2.5,
        storageLocation: 'SH-1',
      ));

      client.addBatch(MobileMockBatchRecord(
        batchId: 'b-02',
        tenantId: tenantA,
        branchId: branchA1,
        productId: 'p-2',
        brandName: 'Ace Plus',
        brandNameBn: 'এইস প্লাস',
        genericName: 'Paracetamol',
        dosageForm: 'TABLET',
        batchNumber: 'B2',
        quantity: 30,
        reserved: 0,
        expiryDate: today.subtract(const Duration(days: 3)),
        isQuarantined: false,
        isRecalled: false,
        costPerUnit: 2.0,
        mrpUnit: 2.5,
        storageLocation: 'SH-2',
      ));

      // Bangla search
      final resSearch = client.queryStock(
        tenantId: tenantA,
        branchId: branchA1,
        search: 'এক্সট্রা',
        userRole: 'BRANCH_MANAGER',
        userBranchId: branchA1,
      );
      expect(resSearch.productsCount, equals(1));
      expect(resSearch.results.first.brandName, equals('Napa Extra'));

      // Filter EXPIRED
      final resExpired = client.queryStock(
        tenantId: tenantA,
        branchId: branchA1,
        expiryStatus: 'EXPIRED',
        userRole: 'BRANCH_MANAGER',
        userBranchId: branchA1,
      );
      expect(resExpired.productsCount, equals(1));
      expect(resExpired.results.first.brandName, equals('Ace Plus'));
    });
  });
}
