// mobile_offline_device_schema_test.dart
// Architecture Decision: ADR-0301 (P301).

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_offline_device_schema_client.dart';

void main() {
  group('P301 MobileOfflineDeviceSchemaClient', () {
    test('01. Owner parses registered offline POS devices with BN lease status', () {
      final client = MobileOfflineDeviceSchemaClient(tenantId: 'ten-1', userRole: 'PHARMACY_OWNER');
      final list = client.parseDeviceList({
        'devices': [
          {
            'registration_id': 'dlreg-1',
            'device_id': 'POS-COUNTER-01',
            'device_label': 'Counter 1',
            'branch_name': 'Dhanmondi',
            'schema_version': 1,
            'is_lease_valid': true,
            'status': 'ACTIVE',
          }
        ],
      });
      expect(list.length, 1);
      expect(list.first.localizedLeaseBadge()['bn'], 'অফলাইন লিজ সক্রিয়');
      expect(client.uiState, DeviceMonitorUiState.loaded);
    });

    test('02. Cashier denied device management', () {
      final client = MobileOfflineDeviceSchemaClient(tenantId: 'ten-1', userRole: 'CASHIER');
      expect(() => client.assertManageAuthorized(), throwsA(isA<OfflineDevicePermissionException>()));
      expect(client.uiState, DeviceMonitorUiState.permissionDenied);
    });
  });
}
