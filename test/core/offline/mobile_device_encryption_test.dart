// mobile_device_encryption_test.dart
// Architecture Decision: ADR-0302 (P302).

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_device_encryption_client.dart';

void main() {
  group('P302 MobileDeviceEncryptionClient', () {
    test('01. Owner parses active encryption key metadata with BN badge', () {
      final client = MobileDeviceEncryptionClient(tenantId: 'ten-1', userRole: 'PHARMACY_OWNER');
      final list = client.parseKeyList({
        'keys': [
          {
            'key_id': 'dkey-1',
            'device_id': 'POS-01',
            'key_version': 2,
            'algorithm': 'AES_256_GCM_ENVELOPE',
            'status': 'ACTIVE',
            'needs_rotation': false,
          }
        ],
      });
      expect(list.length, 1);
      expect(list.first.localizedKeyBadge()['bn'], 'এনক্রিপ্টেড (v2 সক্রিয়)');
      expect(client.uiState, KeyVaultUiState.loaded);
    });

    test('02. Branch Manager denied key rotation/recovery management', () {
      final client = MobileDeviceEncryptionClient(tenantId: 'ten-1', userRole: 'BRANCH_MANAGER');
      expect(() => client.assertManageAuthorized(), throwsA(isA<DeviceEncryptionPermissionException>()));
      expect(client.uiState, KeyVaultUiState.permissionDenied);
    });
  });
}
