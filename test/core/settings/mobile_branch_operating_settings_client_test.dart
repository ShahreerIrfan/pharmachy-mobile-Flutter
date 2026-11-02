// test/core/settings/mobile_branch_operating_settings_client_test.dart
// Unit tests for P116 MobileBranchOperatingSettingsClient (ADR-0116).

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/settings/mobile_branch_operating_settings_client.dart';

void main() {
  group('P116: MobileBranchOperatingSettingsClient Tests', () {
    late MobileBranchOperatingSettingsClient client;
    late MobileBranchSettingsRecord sampleRecord;

    setUp(() {
      client = MobileBranchOperatingSettingsClient();
      sampleRecord = const MobileBranchSettingsRecord(
        settingsId: 'bos-m101',
        tenantId: 'tn-lazz',
        branchId: 'br-dhanmondi',
        branchName: 'Dhanmondi Branch',
        receiptFormat: MobileReceiptFormat(
          paperWidth: '80mm',
          headerText: 'Lazz Pharma Dhanmondi',
          footerText: 'No refunds on opened strips',
        ),
      );
    });

    test('P116: Pharmacy Owner can read and write settings', () {
      final readRes = client.evaluateAccess(
        callerRole: 'PHARMACY_OWNER',
        callerTenantId: 'tn-lazz',
        record: sampleRecord,
        isWriteOperation: false,
      );
      expect(readRes.uiStatus, equals(MobileBranchSettingsUiStatus.success));

      final writeRes = client.evaluateAccess(
        callerRole: 'PHARMACY_OWNER',
        callerTenantId: 'tn-lazz',
        record: sampleRecord,
        isWriteOperation: true,
      );
      expect(writeRes.uiStatus, equals(MobileBranchSettingsUiStatus.success));
    });

    test('P116: Branch Manager can update assigned branch', () {
      final res = client.evaluateAccess(
        callerRole: 'BRANCH_MANAGER',
        callerTenantId: 'tn-lazz',
        callerBranchId: 'br-dhanmondi',
        record: sampleRecord,
        isWriteOperation: true,
      );
      expect(res.uiStatus, equals(MobileBranchSettingsUiStatus.success));
    });

    test('P116: Branch Manager cannot update foreign branch (ERR_CROSS_BRANCH_VIOLATION)', () {
      final res = client.evaluateAccess(
        callerRole: 'BRANCH_MANAGER',
        callerTenantId: 'tn-lazz',
        callerBranchId: 'br-gulshan',
        record: sampleRecord,
        isWriteOperation: true,
      );
      expect(res.uiStatus, equals(MobileBranchSettingsUiStatus.permissionDenied));
      expect(res.errorCode, equals('ERR_CROSS_BRANCH_VIOLATION'));
    });

    test('P116: Cashier can read settings for POS display', () {
      final res = client.evaluateAccess(
        callerRole: 'CASHIER',
        callerTenantId: 'tn-lazz',
        record: sampleRecord,
        isWriteOperation: false,
      );
      expect(res.uiStatus, equals(MobileBranchSettingsUiStatus.success));
    });

    test('P116: Cashier cannot modify operating settings (ERR_PERMISSION_DENIED)', () {
      final res = client.evaluateAccess(
        callerRole: 'CASHIER',
        callerTenantId: 'tn-lazz',
        record: sampleRecord,
        isWriteOperation: true,
      );
      expect(res.uiStatus, equals(MobileBranchSettingsUiStatus.permissionDenied));
      expect(res.errorCode, equals('ERR_PERMISSION_DENIED'));
    });

    test('P116: Cross-tenant access is rejected (ERR_CROSS_TENANT_VIOLATION)', () {
      final res = client.evaluateAccess(
        callerRole: 'PHARMACY_OWNER',
        callerTenantId: 'tn-other-tenant',
        record: sampleRecord,
        isWriteOperation: false,
      );
      expect(res.uiStatus, equals(MobileBranchSettingsUiStatus.permissionDenied));
      expect(res.errorCode, equals('ERR_CROSS_TENANT_VIOLATION'));
    });
  });
}

