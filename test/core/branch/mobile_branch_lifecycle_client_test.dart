// test/core/branch/mobile_branch_lifecycle_client_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/branch/mobile_branch_lifecycle_client.dart';

void main() {
  group('P107: MobileBranchLifecycleClient Tests', () {
    late MobileBranchLifecycleClient client;

    setUp(() {
      client = MobileBranchLifecycleClient();
    });

    test('P107: Owner successfully validates branch store creation', () {
      final res = client.validateBranchCreation(
        tenantId: 'tenant-test-1',
        name: 'Gulshan 2 Flagship Store',
        licenseNumber: 'DGDA-DL-GLS-2026-88',
        actorRole: 'PHARMACY_OWNER',
      );
      expect(res.isValid, isTrue);
      expect(res.errorCode, isEmpty);
    });

    test('P107: Branch Manager and Cashier denied branch creation (RBAC gate)', () {
      final resManager = client.validateBranchCreation(
        tenantId: 'tenant-test-1',
        name: 'Uttara Store',
        licenseNumber: 'DGDA-DL-001',
        actorRole: 'BRANCH_MANAGER',
      );
      expect(resManager.isValid, isFalse);
      expect(resManager.errorCode, 'ERR_PERMISSION_DENIED');
      expect(resManager.messageBn.contains('মালিক'), isTrue);

      final resCashier = client.validateBranchCreation(
        tenantId: 'tenant-test-1',
        name: 'Uttara Store',
        licenseNumber: 'DGDA-DL-001',
        actorRole: 'CASHIER',
      );
      expect(resCashier.isValid, isFalse);
      expect(resCashier.errorCode, 'ERR_PERMISSION_DENIED');
    });

    test('P107: Short name or short license fails validation', () {
      final badName = client.validateBranchCreation(
        tenantId: 'tenant-test-1',
        name: 'A',
        licenseNumber: 'DGDA-DL-001',
        actorRole: 'PHARMACY_OWNER',
      );
      expect(badName.isValid, isFalse);
      expect(badName.errorCode, 'ERR_INVALID_BRANCH_NAME');

      final badLic = client.validateBranchCreation(
        tenantId: 'tenant-test-1',
        name: 'Valid Name',
        licenseNumber: 'DG',
        actorRole: 'PHARMACY_OWNER',
      );
      expect(badLic.isValid, isFalse);
      expect(badLic.errorCode, 'ERR_INVALID_LICENSE');
    });

    test('P107: Branch closure requires detailed reason and owner permissions', () {
      final shortReason = client.validateBranchClosure(
        branchId: 'br-001',
        reason: 'no',
        actorRole: 'PHARMACY_OWNER',
      );
      expect(shortReason.isValid, isFalse);
      expect(shortReason.errorCode, 'ERR_CLOSURE_REASON_REQUIRED');

      final unauthorized = client.validateBranchClosure(
        branchId: 'br-001',
        reason: 'Valid closure reason here',
        actorRole: 'BRANCH_MANAGER',
      );
      expect(unauthorized.isValid, isFalse);
      expect(unauthorized.errorCode, 'ERR_PERMISSION_DENIED');

      final ok = client.validateBranchClosure(
        branchId: 'br-001',
        reason: 'Commercial lease expired; consolidating inventory',
        actorRole: 'PHARMACY_OWNER',
      );
      expect(ok.isValid, isTrue);
    });

    test('P107: Suspension and closure transitions strictly preserve historical records', () {
      const record = MobileBranchLifecycleRecord(
        branchId: 'br-uttara-01',
        tenantId: 'tenant-test-1',
        name: 'Uttara Store',
        branchCode: 'BR-UTT-01',
        licenseNumber: 'DGDA-DL-2026-99',
        address: 'Sector 3, Uttara, Dhaka',
        phoneNumber: '+8801700000000',
        email: 'uttara@primepharma.com',
        managerName: 'Manager Kamal',
        isMainBranch: true,
        status: 'ACTIVE',
        isActive: true,
        isOverQuotaLocked: false,
        activeStaffCount: 5,
        activeDevicesCount: 2,
        historicalInvoicesCount: 4200,
        historicalStockBatchesCount: 780,
        createdAt: '2025-01-01T00:00:00Z',
      );

      final suspState = client.applySuspension(record, 'Renovation notice', 'owner_kamal');
      expect(suspState.status, MobileBranchLifecycleUiStatus.success);
      expect(suspState.record?.status, 'SUSPENDED');
      expect(suspState.record?.isActive, isFalse);
      expect(suspState.record?.historicalInvoicesCount, 4200); // 100% preserved
      expect(suspState.record?.historicalStockBatchesCount, 780); // 100% preserved

      final closeState = client.applyClosure(record, 'Permanent closure due to road expansion', 'owner_kamal');
      expect(closeState.status, MobileBranchLifecycleUiStatus.success);
      expect(closeState.record?.status, 'CLOSED');
      expect(closeState.record?.isActive, isFalse);
      expect(closeState.record?.isMainBranch, isFalse);
      expect(closeState.record?.historicalInvoicesCount, 4200); // 100% preserved
      expect(closeState.record?.historicalStockBatchesCount, 780); // 100% preserved
      expect(closeState.record?.closedAt, isNotNull);
    });

    test('P107: Offline fallback returns cached branch profile with translated guidance', () {
      const record = MobileBranchLifecycleRecord(
        branchId: 'br-cache-1',
        tenantId: 'tenant-test-1',
        name: 'Cached Branch Store',
        branchCode: 'BR-CACHE-01',
        licenseNumber: 'DGDA-DL-2026-000',
        address: 'Address',
        phoneNumber: '+8801700000000',
        managerName: 'Manager',
        isMainBranch: false,
        status: 'ACTIVE',
        isActive: true,
        isOverQuotaLocked: false,
        activeStaffCount: 2,
        activeDevicesCount: 1,
        historicalInvoicesCount: 200,
        historicalStockBatchesCount: 40,
        createdAt: '2026-01-01T00:00:00Z',
      );
      client.cacheRecord(record);

      final state = client.toOfflineState('br-cache-1');
      expect(state.status, MobileBranchLifecycleUiStatus.offline);
      expect(state.isOffline, isTrue);
      expect(state.record?.name, 'Cached Branch Store');
      expect(state.errorMessageBn.contains('অফলাইন'), isTrue);
    });
  });
}
