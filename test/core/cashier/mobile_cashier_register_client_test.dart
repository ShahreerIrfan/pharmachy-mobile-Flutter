// test/core/cashier/mobile_cashier_register_client_test.dart
// Unit tests for P117 Cashier Register Assignment mobile client.

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/cashier/mobile_cashier_register_client.dart';

void main() {
  group('MobileCashierRegisterClient Tests', () {
    late MobileCashierRegisterClient client;
    late List<CashierRegisterAssignmentRecord> existingAssignments;

    setUp(() {
      client = MobileCashierRegisterClient();
      existingAssignments = [];
    });

    test('Owner assigns unassigned register successfully', () {
      final result = client.attemptAssignment(
        existingAssignments: existingAssignments,
        callerRole: 'PHARMACY_OWNER',
        callerTenantId: 'tenant-1',
        callerBranchId: 'branch-1',
        callerStaffId: 'staff-owner',
        targetTenantId: 'tenant-1',
        targetBranchId: 'branch-1',
        targetRegisterId: 'REG-01',
        targetCashierId: 'staff-c1',
        targetCashierName: 'Fatima',
        openingFloatAmount: 1000.0,
      );

      expect(result.uiStatus, MobileCashierUiStatus.success);
      expect(result.record, isNotNull);
      expect(result.record!.registerId, 'REG-01');
      expect(result.record!.cashierName, 'Fatima');
      expect(result.record!.status, 'ACTIVE');
      expect(result.record!.openingFloatAmount, 1000.0);
    });

    test('Reject concurrent assignment if register is already active', () {
      existingAssignments.add(CashierRegisterAssignmentRecord(
        assignmentId: 'assign-1',
        tenantId: 'tenant-1',
        branchId: 'branch-1',
        registerId: 'REG-01',
        cashierId: 'staff-c1',
        cashierName: 'Fatima',
        openingFloatAmount: 500.0,
        closingFloatAmount: null,
        status: 'ACTIVE',
        assignedAt: '2026-11-02T09:00:00Z',
      ));

      final result = client.attemptAssignment(
        existingAssignments: existingAssignments,
        callerRole: 'PHARMACY_OWNER',
        callerTenantId: 'tenant-1',
        callerBranchId: 'branch-1',
        callerStaffId: 'staff-owner',
        targetTenantId: 'tenant-1',
        targetBranchId: 'branch-1',
        targetRegisterId: 'REG-01',
        targetCashierId: 'staff-c2',
        targetCashierName: 'Tariq',
        openingFloatAmount: 500.0,
      );

      expect(result.uiStatus, MobileCashierUiStatus.error);
      expect(result.errorCode, 'ERR_REGISTER_ALREADY_ASSIGNED');
      expect(result.record, isNull);
    });

    test('Reject concurrent assignment if cashier is already operating another register', () {
      existingAssignments.add(CashierRegisterAssignmentRecord(
        assignmentId: 'assign-1',
        tenantId: 'tenant-1',
        branchId: 'branch-1',
        registerId: 'REG-01',
        cashierId: 'staff-c1',
        cashierName: 'Fatima',
        openingFloatAmount: 500.0,
        closingFloatAmount: null,
        status: 'ACTIVE',
        assignedAt: '2026-11-02T09:00:00Z',
      ));

      final result = client.attemptAssignment(
        existingAssignments: existingAssignments,
        callerRole: 'PHARMACY_OWNER',
        callerTenantId: 'tenant-1',
        callerBranchId: 'branch-1',
        callerStaffId: 'staff-owner',
        targetTenantId: 'tenant-1',
        targetBranchId: 'branch-1',
        targetRegisterId: 'REG-02',
        targetCashierId: 'staff-c1',
        targetCashierName: 'Fatima',
        openingFloatAmount: 500.0,
      );

      expect(result.uiStatus, MobileCashierUiStatus.error);
      expect(result.errorCode, 'ERR_CASHIER_ALREADY_ASSIGNED');
      expect(result.record, isNull);
    });

    test('Branch Manager cross branch assignment is rejected', () {
      final result = client.attemptAssignment(
        existingAssignments: existingAssignments,
        callerRole: 'BRANCH_MANAGER',
        callerTenantId: 'tenant-1',
        callerBranchId: 'branch-1',
        callerStaffId: 'staff-mgr',
        targetTenantId: 'tenant-1',
        targetBranchId: 'branch-2',
        targetRegisterId: 'REG-01',
        targetCashierId: 'staff-c1',
        targetCashierName: 'Fatima',
        openingFloatAmount: 500.0,
      );

      expect(result.uiStatus, MobileCashierUiStatus.permissionDenied);
      expect(result.errorCode, 'ERR_CROSS_BRANCH_VIOLATION');
    });

    test('Cashier assigning another staff member is rejected', () {
      final result = client.attemptAssignment(
        existingAssignments: existingAssignments,
        callerRole: 'CASHIER',
        callerTenantId: 'tenant-1',
        callerBranchId: 'branch-1',
        callerStaffId: 'staff-c1',
        targetTenantId: 'tenant-1',
        targetBranchId: 'branch-1',
        targetRegisterId: 'REG-01',
        targetCashierId: 'staff-c2',
        targetCashierName: 'Tariq',
        openingFloatAmount: 500.0,
      );

      expect(result.uiStatus, MobileCashierUiStatus.permissionDenied);
      expect(result.errorCode, 'ERR_PERMISSION_DENIED');
    });

    test('Cross tenant assignment is forbidden', () {
      final result = client.attemptAssignment(
        existingAssignments: existingAssignments,
        callerRole: 'PHARMACY_OWNER',
        callerTenantId: 'tenant-1',
        callerBranchId: 'branch-1',
        callerStaffId: 'staff-owner',
        targetTenantId: 'tenant-2',
        targetBranchId: 'branch-99',
        targetRegisterId: 'REG-01',
        targetCashierId: 'staff-c1',
        targetCashierName: 'Fatima',
        openingFloatAmount: 500.0,
      );

      expect(result.uiStatus, MobileCashierUiStatus.permissionDenied);
      expect(result.errorCode, 'ERR_CROSS_TENANT_VIOLATION');
    });
  });
}
