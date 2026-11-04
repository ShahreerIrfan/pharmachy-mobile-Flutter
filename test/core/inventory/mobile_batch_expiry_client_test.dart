import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/inventory/mobile_batch_expiry_client.dart';

void main() {
  group('P172 MobileBatchExpiryClient Tests', () {
    final today = DateTime(2026, 11, 4);

    test('Test 1: Tier classification across all threshold windows', () {
      final client = MobileBatchExpiryClient(
        tenantId: 'tenant-dhanmondi',
        branchId: 'branch-main',
        userRole: 'CASHIER',
        policy: const MobileExpiryPolicy(
          warningLeadDays: 90,
          criticalLeadDays: 30,
          quarantineLeadDays: 15,
          saleCutoffLeadDays: 7,
        ),
      );

      // Safe: 120 days
      final safe = client.evaluateBatch(
        batchId: 'b1',
        batchNumber: 'BAT-120',
        productName: 'Napa',
        expiryDate: today.add(const Duration(days: 120)),
        asOfDate: today,
      );
      expect(safe.tier, equals(MobileExpiryTier.normalSafe));
      expect(safe.isSaleBlocked, isFalse);

      // Early Warning: 60 days
      final early = client.evaluateBatch(
        batchId: 'b2',
        batchNumber: 'BAT-60',
        productName: 'Napa',
        expiryDate: today.add(const Duration(days: 60)),
        asOfDate: today,
      );
      expect(early.tier, equals(MobileExpiryTier.earlyWarning));
      expect(early.isSaleBlocked, isFalse);

      // Near Expiry: 25 days
      final critical = client.evaluateBatch(
        batchId: 'b3',
        batchNumber: 'BAT-25',
        productName: 'Napa',
        expiryDate: today.add(const Duration(days: 25)),
        asOfDate: today,
      );
      expect(critical.tier, equals(MobileExpiryTier.nearExpiryCritical));
      expect(critical.isSaleBlocked, isFalse);

      // Urgent Quarantine: 10 days
      final quar = client.evaluateBatch(
        batchId: 'b4',
        batchNumber: 'BAT-10',
        productName: 'Napa',
        expiryDate: today.add(const Duration(days: 10)),
        asOfDate: today,
      );
      expect(quar.tier, equals(MobileExpiryTier.quarantineDisposition));

      // Cutoff Blocked: 5 days
      final cutoff = client.evaluateBatch(
        batchId: 'b5',
        batchNumber: 'BAT-5',
        productName: 'Napa',
        expiryDate: today.add(const Duration(days: 5)),
        asOfDate: today,
      );
      expect(cutoff.tier, equals(MobileExpiryTier.cutoffBlocked));
      expect(cutoff.isSaleBlocked, isTrue);

      // Expired: -2 days
      final exp = client.evaluateBatch(
        batchId: 'b6',
        batchNumber: 'BAT-EXP',
        productName: 'Napa',
        expiryDate: today.subtract(const Duration(days: 2)),
        asOfDate: today,
      );
      expect(exp.tier, equals(MobileExpiryTier.expired));
      expect(exp.isSaleBlocked, isTrue);
    });

    test('Test 2: Hard block on expired batches (Cannot be bypassed)', () {
      final client = MobileBatchExpiryClient(
        tenantId: 'tenant-dhanmondi',
        branchId: 'branch-main',
        userRole: 'BRANCH_MANAGER',
      );

      final exp = client.evaluateBatch(
        batchId: 'b-exp',
        batchNumber: 'BAT-EXP',
        productName: 'Ace',
        expiryDate: today.subtract(const Duration(days: 1)),
        asOfDate: today,
      );
      expect(exp.tier, equals(MobileExpiryTier.expired));

      final res = client.verifyBatchForSale(eval: exp, isManagerAuthorized: true);
      expect(res.success, isFalse);
      expect(res.errorCode, equals('ERR_BATCH_EXPIRED'));
    });

    test('Test 3: Sale cutoff guard and manager override behaviour', () {
      final clientStrict = MobileBatchExpiryClient(
        tenantId: 'tenant-dhanmondi',
        branchId: 'branch-main',
        userRole: 'CASHIER',
        policy: const MobileExpiryPolicy(
          saleCutoffLeadDays: 7,
          allowManagerOverrideNearExpiry: false,
        ),
      );

      final cutoffBatch = clientStrict.evaluateBatch(
        batchId: 'b-cut',
        batchNumber: 'BAT-CUT',
        productName: 'Seclo',
        expiryDate: today.add(const Duration(days: 4)),
        asOfDate: today,
      );

      final resBlocked = clientStrict.verifyBatchForSale(eval: cutoffBatch, isManagerAuthorized: false);
      expect(resBlocked.success, isFalse);
      expect(resBlocked.errorCode, equals('ERR_SALE_CUTOFF_BREACHED'));

      // Override enabled
      final clientOverride = MobileBatchExpiryClient(
        tenantId: 'tenant-dhanmondi',
        branchId: 'branch-main',
        userRole: 'BRANCH_MANAGER',
        policy: const MobileExpiryPolicy(
          saleCutoffLeadDays: 7,
          allowManagerOverrideNearExpiry: true,
        ),
      );

      final resApproved = clientOverride.verifyBatchForSale(eval: cutoffBatch, isManagerAuthorized: true);
      expect(resApproved.success, isTrue);
    });

    test('Test 4: RBAC and suspended tenant enforcement', () {
      final clientSuspended = MobileBatchExpiryClient(
        tenantId: 'tenant-dhanmondi',
        branchId: 'branch-main',
        isTenantSuspended: true,
      );
      final safeBatch = clientSuspended.evaluateBatch(
        batchId: 'b-safe',
        batchNumber: 'BAT-SAFE',
        productName: 'Napa',
        expiryDate: today.add(const Duration(days: 100)),
        asOfDate: today,
      );

      final resSusp = clientSuspended.verifyBatchForSale(eval: safeBatch);
      expect(resSusp.success, isFalse);
      expect(resSusp.errorCode, equals('ERR_TENANT_SUSPENDED'));

      final clientUnauth = MobileBatchExpiryClient(
        tenantId: 'tenant-dhanmondi',
        branchId: 'branch-main',
        userRole: 'ACCOUNTANT_ASSISTANT',
      );
      final resUnauth = clientUnauth.verifyBatchForSale(eval: safeBatch);
      expect(resUnauth.success, isFalse);
      expect(resUnauth.errorCode, equals('ERR_ROLE_UNAUTHORIZED'));
    });
  });
}

