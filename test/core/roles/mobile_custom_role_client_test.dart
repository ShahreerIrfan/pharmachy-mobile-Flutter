// test/core/roles/mobile_custom_role_client_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/roles/mobile_custom_role_client.dart';

void main() {
  group('MobileCustomRoleClient Tests', () {
    test('enforces PCB qualification safety minimum on Rx dispensing', () {
      // Missing PCB qualification
      final invalidRes = MobileRoleValidationResult.validate(
        roleCode: 'ROLE_UNQUALIFIED',
        displayName: 'Unqualified Dispenser',
        permissions: ['dispense:rx_antibiotics', 'sales:checkout'],
        requiresPcbRegistration: false,
      );
      expect(invalidRes.isValid, isFalse);
      expect(invalidRes.errorCode, 'ERR_SAFETY_MINIMUM_PCB_REQUIRED');

      // Valid with PCB qualification
      final validRes = MobileRoleValidationResult.validate(
        roleCode: 'ROLE_QUALIFIED',
        displayName: 'Qualified Pharmacist',
        permissions: ['dispense:rx_antibiotics', 'sales:checkout'],
        requiresPcbRegistration: true,
      );
      expect(validRes.isValid, isTrue);
    });

    test('parses custom roles payload and detects clinical dispensing capability', () {
      final samplePayload = [
        {
          'role_id': 'role-test12345',
          'tenant_id': 'tn-prime',
          'role_code': 'ROLE_NIGHT_LEAD',
          'display_name': 'Night Shift Lead',
          'description': 'Handles night shifts and prescription checks',
          'base_role': 'PHARMACIST',
          'permission_keys': ['dispense:rx_antibiotics', 'sales:checkout'],
          'requires_pcb_registration': true,
          'is_system_protected': false,
          'is_archived': false,
          'cloned_from_id': 'role-system-pharmacist',
        }
      ];

      final state = MobileRoleState.fromPayload(samplePayload);
      expect(state.uiStatus, MobileRoleUiStatus.success);
      expect(state.roles.length, 1);
      expect(state.roles.first.roleCode, 'ROLE_NIGHT_LEAD');
      expect(state.roles.first.allowsClinicalDispensing, isTrue);
    });

    test('handles offline and permission denied states cleanly', () {
      final offlineState = MobileRoleState.offline();
      expect(offlineState.uiStatus, MobileRoleUiStatus.offline);
      expect(offlineState.messageBn, contains('অফলাইন মোড'));

      final deniedState = MobileRoleState.permissionDenied('CASHIER');
      expect(deniedState.uiStatus, MobileRoleUiStatus.permissionDenied);
      expect(deniedState.messageEn, contains('CASHIER'));
      expect(deniedState.messageBn, contains('অনুমতি নেই'));
    });
  });
}
