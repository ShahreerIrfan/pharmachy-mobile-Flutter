// test/core/staff/mobile_staff_invitation_client_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/staff/mobile_staff_invitation_client.dart';

void main() {
  group('MobileStaffInvitationClient Tests', () {
    test('parses invitations and memberships properly from API responses', () {
      final sampleInvs = [
        {
          'invitation_id': 'inv-abc12345',
          'tenant_id': 'tn-prime',
          'branch_id': 'br-dhaka',
          'branch_name': 'Dhaka Central',
          'email': 'salim@pharmacy.com',
          'full_name': 'Salim Khan',
          'role': 'CASHIER',
          'custom_role_title': 'Front Counter Cashier',
          'status': 'PENDING',
          'expires_at': '2026-11-08T12:00:00Z',
          'resend_count': 1,
        }
      ];

      final sampleMems = [
        {
          'membership_id': 'mem-xyz98765',
          'tenant_id': 'tn-prime',
          'staff_id': 'stf-001',
          'username': 'salim_khan',
          'full_name': 'Salim Khan',
          'primary_branch_id': 'br-dhaka',
          'primary_branch_name': 'Dhaka Central',
          'assigned_branch_ids': ['br-dhaka', 'br-uttara'],
          'role': 'CASHIER',
          'custom_role_title': 'Front Counter Cashier',
          'is_active': true,
          'joined_at': '2026-11-01T10:00:00Z',
        }
      ];

      final state = MobileStaffState.fromPayload(
        rawInvitations: sampleInvs,
        rawMemberships: sampleMems,
      );

      expect(state.uiStatus, MobileStaffUiStatus.success);
      expect(state.invitations.length, 1);
      expect(state.invitations.first.invitationId, 'inv-abc12345');
      expect(state.invitations.first.isPending, isTrue);
      expect(state.invitations.first.resendCount, 1);

      expect(state.memberships.length, 1);
      expect(state.memberships.first.membershipId, 'mem-xyz98765');
      expect(state.memberships.first.assignedBranchIds, contains('br-uttara'));
      expect(state.memberships.first.isActive, isTrue);
    });

    test('generates valid offline and permission denied states', () {
      final offlineState = MobileStaffState.offline();
      expect(offlineState.uiStatus, MobileStaffUiStatus.offline);
      expect(offlineState.messageBn, contains('অফলাইন মোড'));

      final deniedState = MobileStaffState.permissionDenied('CASHIER');
      expect(deniedState.uiStatus, MobileStaffUiStatus.permissionDenied);
      expect(deniedState.messageEn, contains('CASHIER'));
      expect(deniedState.messageBn, contains('অনুমতি নেই'));
    });
  });
}
