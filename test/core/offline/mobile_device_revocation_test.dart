import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/offline/mobile_device_revocation_client.dart';

void main() {
  group('P319 MobileDeviceRevocationClient Tests', () {
    late MobileDeviceRevocationClient client;

    setUp(() {
      client = MobileDeviceRevocationClient();
    });

    test('Initial state is unlocked and operational', () {
      expect(client.isLocked, false);
      expect(() => client.assertOperational(), returnsNormally);
    });

    test('Locking device blocks operations and records reason', () {
      client.lockDevice('Suspected clone or stolen terminal');
      expect(client.isLocked, true);
      expect(client.revocationReason, 'Suspected clone or stolen terminal');
      expect(() => client.assertOperational(), throwsStateError);
      expect(client.getSecurityLockdownMessage().contains('DEVICE REVOKED'), true);
    });

    test('Packs unsynced outbox evidence safely for owner recovery', () {
      final unsynced = [
        {'command_id': 'CMD-1', 'amount': '250.00'},
        {'command_id': 'CMD-2', 'amount': '120.00'},
      ];

      final packed = client.packUnsyncedEvidence(
        deviceId: 'POS-MOB-001',
        unsyncedCommands: unsynced,
      );

      expect(packed['device_id'], 'POS-MOB-001');
      expect(packed['unsynced_command_count'], 2);
      expect(packed.containsKey('quarantined_at'), true);
    });
  });
}
