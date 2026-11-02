// test/core/analytics/mobile_staff_performance_client_test.dart
// Unit tests for P115 MobileStaffPerformanceClient (ADR-0115).

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/analytics/mobile_staff_performance_client.dart';

void main() {
  group('P115: MobileStaffPerformanceClient Tests', () {
    late MobileStaffPerformanceClient client;
    late List<MobileStaffPerformanceRecord> sampleRecords;

    setUp(() {
      client = MobileStaffPerformanceClient();
      sampleRecords = const [
        MobileStaffPerformanceRecord(
          snapshotId: 'spm-m1',
          tenantId: 'tn-lazz',
          branchId: 'br-dhanmondi',
          staffId: 'stf-c1',
          staffName: 'Rahim Cashier',
          staffRole: 'CASHIER',
          metricDate: '2026-11-02',
          totalSalesCount: 45,
          totalSalesAmount: 125000.0,
          totalRefundsCount: 2,
          totalRefundsAmount: 3500.0,
          netRevenue: 121500.0,
          reconciliationVarianceAmount: 0.0,
          reconciliationStatus: 'BALANCED',
          reportingFreshnessSeconds: 120,
        ),
        MobileStaffPerformanceRecord(
          snapshotId: 'spm-m2',
          tenantId: 'tn-lazz',
          branchId: 'br-dhanmondi',
          staffId: 'stf-c2',
          staffName: 'Karim Cashier',
          staffRole: 'CASHIER',
          metricDate: '2026-11-02',
          totalSalesCount: 30,
          totalSalesAmount: 80000.0,
          totalRefundsCount: 1,
          totalRefundsAmount: 1000.0,
          netRevenue: 79000.0,
          reconciliationVarianceAmount: -200.0,
          reconciliationStatus: 'SHORTAGE',
          reportingFreshnessSeconds: 45,
        ),
        MobileStaffPerformanceRecord(
          snapshotId: 'spm-m3',
          tenantId: 'tn-lazz',
          branchId: 'br-gulshan',
          staffId: 'stf-g1',
          staffName: 'Gulshan Cashier',
          staffRole: 'CASHIER',
          metricDate: '2026-11-02',
          totalSalesCount: 50,
          totalSalesAmount: 150000.0,
          totalRefundsCount: 0,
          totalRefundsAmount: 0.0,
          netRevenue: 150000.0,
          reconciliationVarianceAmount: 50.0,
          reconciliationStatus: 'OVERAGE',
          reportingFreshnessSeconds: 15,
        ),
      ];
    });

    test('P115: Pharmacy Owner sees all staff records across branches', () {
      final res = client.filterMetrics(
        allRecords: sampleRecords,
        callerRole: 'PHARMACY_OWNER',
        callerTenantId: 'tn-lazz',
      );
      expect(res.uiStatus, equals(MobileStaffPerformanceUiStatus.success));
      expect(res.records.length, equals(3));
    });

    test('P115: Branch Manager is strictly scoped to assigned branch', () {
      final res = client.filterMetrics(
        allRecords: sampleRecords,
        callerRole: 'BRANCH_MANAGER',
        callerTenantId: 'tn-lazz',
        callerBranchId: 'br-dhanmondi',
      );
      expect(res.uiStatus, equals(MobileStaffPerformanceUiStatus.success));
      expect(res.records.length, equals(2));
    });

    test('P115: Branch Manager cannot query another branch (ERR_CROSS_BRANCH_VIOLATION)', () {
      final res = client.filterMetrics(
        allRecords: sampleRecords,
        callerRole: 'BRANCH_MANAGER',
        callerTenantId: 'tn-lazz',
        callerBranchId: 'br-dhanmondi',
        targetBranchId: 'br-gulshan',
      );
      expect(res.uiStatus, equals(MobileStaffPerformanceUiStatus.permissionDenied));
      expect(res.errorCode, equals('ERR_CROSS_BRANCH_VIOLATION'));
    });

    test('P115: Cashier is restricted to self-only metrics', () {
      final res = client.filterMetrics(
        allRecords: sampleRecords,
        callerRole: 'CASHIER',
        callerTenantId: 'tn-lazz',
        callerBranchId: 'br-dhanmondi',
        callerStaffId: 'stf-c1',
      );
      expect(res.uiStatus, equals(MobileStaffPerformanceUiStatus.success));
      expect(res.records.length, equals(1));
      expect(res.records.first.staffId, equals('stf-c1'));
    });

    test('P115: Cashier attempting to view another staff is denied', () {
      final res = client.filterMetrics(
        allRecords: sampleRecords,
        callerRole: 'CASHIER',
        callerTenantId: 'tn-lazz',
        callerBranchId: 'br-dhanmondi',
        callerStaffId: 'stf-c1',
        targetStaffId: 'stf-c2',
      );
      expect(res.uiStatus, equals(MobileStaffPerformanceUiStatus.permissionDenied));
      expect(res.errorCode, equals('ERR_PERMISSION_DENIED'));
    });

    test('P115: Cross-tenant query is denied (ERR_CROSS_TENANT_VIOLATION)', () {
      final res = client.filterMetrics(
        allRecords: sampleRecords,
        callerRole: 'PHARMACY_OWNER',
        callerTenantId: 'tn-lazz',
        targetTenantId: 'tn-foreign-corp',
      );
      expect(res.uiStatus, equals(MobileStaffPerformanceUiStatus.permissionDenied));
      expect(res.errorCode, equals('ERR_CROSS_TENANT_VIOLATION'));
    });
  });
}

