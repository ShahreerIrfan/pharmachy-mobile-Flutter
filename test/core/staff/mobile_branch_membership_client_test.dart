// test/core/staff/mobile_branch_membership_client_test.dart
// Architecture Decision: ADR-0105
// Phase 06: Milestone M03 - Branch-Specific Membership (P105)

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/staff/mobile_branch_membership_client.dart';

void main() {
  group('MobileBranchMembershipClient Tests (ADR-0105)', () {
    test('Staff account holds different roles in separate authorized branches', () {
      const b1 = MobileBranchMembershipRecord(
        membershipId: 'bsm-1',
        tenantId: 'tn-prime',
        staffMemberId: 'stf-kamal',
        staffName: 'Kamal Hossain',
        staffUsername: 'kamal@pharmacy.local',
        branchId: 'br-dhanmondi',
        branchName: 'Dhanmondi Branch',
        role: 'BRANCH_MANAGER',
        customRoleCode: '',
        customRoleTitle: 'Store Lead',
        isPrimary: true,
        isActive: true,
        assignedByUsername: 'owner',
        revocationReason: '',
      );

      const b2 = MobileBranchMembershipRecord(
        membershipId: 'bsm-2',
        tenantId: 'tn-prime',
        staffMemberId: 'stf-kamal',
        staffName: 'Kamal Hossain',
        staffUsername: 'kamal@pharmacy.local',
        branchId: 'br-gulshan',
        branchName: 'Gulshan Branch',
        role: 'CASHIER',
        customRoleCode: '',
        customRoleTitle: 'Shift Cashier',
        isPrimary: false,
        isActive: true,
        assignedByUsername: 'owner',
        revocationReason: '',
      );

      final list = [b1, b2];

      final dhanmondi = MobileBranchMembershipClient.resolveEffectiveRole(list, 'br-dhanmondi');
      expect(dhanmondi, isNotNull);
      expect(dhanmondi!.role, equals('BRANCH_MANAGER'));
      expect(dhanmondi.isPrimary, isTrue);

      final gulshan = MobileBranchMembershipClient.resolveEffectiveRole(list, 'br-gulshan');
      expect(gulshan, isNotNull);
      expect(gulshan!.role, equals('CASHIER'));
      expect(gulshan.isPrimary, isFalse);

      final nonExistent = MobileBranchMembershipClient.resolveEffectiveRole(list, 'br-uttara');
      expect(nonExistent, isNull);
    });

    test('Pharmacy Owner has universal assignment authority', () {
      final res = MobileBranchMembershipClient.validateAssignment(
        callerRole: 'PHARMACY_OWNER',
        targetBranchId: 'br-gulshan',
        targetRole: 'BRANCH_MANAGER',
      );
      expect(res['isValid'], isTrue);
      expect(res['errorCode'], isNull);
    });

    test('Branch Manager cannot assign staff to another branch', () {
      final res = MobileBranchMembershipClient.validateAssignment(
        callerRole: 'BRANCH_MANAGER',
        callerBranchId: 'br-dhanmondi',
        targetBranchId: 'br-gulshan',
        targetRole: 'CASHIER',
      );
      expect(res['isValid'], isFalse);
      expect(res['errorCode'], equals('ERR_BRANCH_ACCESS_DENIED'));
    });

    test('Branch Manager cannot assign managerial role', () {
      final res = MobileBranchMembershipClient.validateAssignment(
        callerRole: 'BRANCH_MANAGER',
        callerBranchId: 'br-dhanmondi',
        targetBranchId: 'br-dhanmondi',
        targetRole: 'BRANCH_MANAGER',
      );
      expect(res['isValid'], isFalse);
      expect(res['errorCode'], equals('ERR_PERMISSION_DENIED'));
    });

    test('Serialization and deserialization matches contract schema', () {
      final json = {
        'membership_id': 'bsm-101',
        'tenant_id': 'tn-prime',
        'staff_member_id': 'stf-007',
        'staff_name': 'Rahim',
        'staff_username': 'rahim@pharmacy.local',
        'branch_id': 'br-main',
        'branch_name': 'Main Branch',
        'role': 'STAFF_PHARMACIST',
        'custom_role_code': '',
        'custom_role_title': 'Grade-A Dispenser',
        'is_primary': true,
        'is_active': true,
        'assigned_at': '2026-11-02T10:00:00Z',
        'assigned_by_username': 'owner',
        'revoked_at': null,
        'revocation_reason': '',
      };

      final record = MobileBranchMembershipRecord.fromJson(json);
      expect(record.membershipId, equals('bsm-101'));
      expect(record.role, equals('STAFF_PHARMACIST'));
      expect(record.isPrimary, isTrue);

      final serialized = record.toJson();
      expect(serialized['branch_id'], equals('br-main'));
      expect(serialized['role'], equals('STAFF_PHARMACIST'));
    });

    test('ViewState handles transitions across loading, success, empty, and offline', () {
      final loading = MobileBranchMembershipViewState.loading();
      expect(loading.status, equals(MobileBranchMembershipUiStatus.loading));

      final empty = MobileBranchMembershipViewState.success([]);
      expect(empty.status, equals(MobileBranchMembershipUiStatus.empty));

      final offlineRec = MobileBranchMembershipClient.createOfflineFallback(
        staffMemberId: 'stf-1',
        staffName: 'Rahim',
        branchId: 'br-1',
        branchName: 'Main Branch',
        role: 'CASHIER',
      );
      final offline = MobileBranchMembershipViewState.offline([offlineRec]);
      expect(offline.status, equals(MobileBranchMembershipUiStatus.offline));
      expect(offline.memberships.length, equals(1));
    });
  });
}
