import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/device/mobile_device_registration_client.dart';

void main() {
  group('P111: MobileDeviceRegistrationClient Tests', () {
    const sampleEd25519Pub =
        '-----BEGIN PUBLIC KEY-----\nMCowBQYDK2VwAyEA9fVbK1b9Lz4N6pQ8rX1yA3s5u7w9y1z3b5d7f9h1j3k=\n-----END PUBLIC KEY-----';
    const anotherEd25519Pub =
        '-----BEGIN PUBLIC KEY-----\nMCowBQYDK2VwAyEAMN9bK1b9Lz4N6pQ8rX1yA3s5u7w9y1z3b5d7f9h1j99=\n-----END PUBLIC KEY-----';

    late MobileDeviceRegistrationClient ownerClient;
    late MobileDeviceRegistrationClient managerBranch1Client;
    late MobileDeviceRegistrationClient cashierClient;

    setUp(() {
      ownerClient = MobileDeviceRegistrationClient(
        baseUrl: 'http://localhost:8000/api/v2',
        tenantId: 'tn-lazz-pharma',
        userRole: 'PHARMACY_OWNER',
        username: 'owner_kabir',
      );

      managerBranch1Client = MobileDeviceRegistrationClient(
        baseUrl: 'http://localhost:8000/api/v2',
        tenantId: 'tn-lazz-pharma',
        userRole: 'BRANCH_MANAGER',
        userBranchId: 'br-dhanmondi-01',
        username: 'mgr_tariq',
      );

      cashierClient = MobileDeviceRegistrationClient(
        baseUrl: 'http://localhost:8000/api/v2',
        tenantId: 'tn-lazz-pharma',
        userRole: 'CASHIER',
        userBranchId: 'br-dhanmondi-01',
        username: 'csh_rahim',
      );
    });

    test('P111: Workstation registers with public key, generates 64-char SHA-256 fingerprint in PENDING_APPROVAL', () {
      final record = ownerClient.registerDevice(
        branchId: 'br-dhanmondi-01',
        deviceId: 'term-pos-mob-01',
        deviceLabel: 'Counter 1 - Fast Dispensing Desk',
        publicKeyPem: sampleEd25519Pub,
        hardwareFingerprint: 'HW-XYZ-9988-77',
        macAddress: '00:1A:2B:3C:4D:5E',
      );

      expect(record.registrationId.startsWith('dreg-'), isTrue);
      expect(record.deviceId, equals('term-pos-mob-01'));
      expect(record.deviceLabel, equals('Counter 1 - Fast Dispensing Desk'));
      expect(record.status, equals('PENDING_APPROVAL'));
      expect(record.keyFingerprint.length, equals(64));

      final manualFp = computeSha256Fingerprint(sampleEd25519Pub);
      expect(record.keyFingerprint, equals(manualFp));
    });

    test('P111: Owner approves device, transitioning to APPROVED', () {
      final reg = ownerClient.registerDevice(
        branchId: 'br-dhanmondi-01',
        deviceId: 'term-pos-mob-02',
        deviceLabel: 'Counter 2 - Main POS',
        publicKeyPem: sampleEd25519Pub,
      );

      final approved = ownerClient.approveDevice(
        reg.registrationId,
        notes: 'Mobile owner approved terminal',
      );

      expect(approved.status, equals('APPROVED'));
      expect(approved.approvedBy, equals('owner_kabir'));
      expect(approved.approvalNotes, equals('Mobile owner approved terminal'));
    });

    test('P111: Branch Manager can approve device belonging to their assigned branch', () {
      final reg = managerBranch1Client.registerDevice(
        branchId: 'br-dhanmondi-01',
        deviceId: 'term-pos-mob-03',
        deviceLabel: 'Counter 3 - Dhanmondi Desk',
        publicKeyPem: sampleEd25519Pub,
      );

      final approved = managerBranch1Client.approveDevice(
        reg.registrationId,
        notes: 'Verified station',
      );

      expect(approved.status, equals('APPROVED'));
      expect(approved.approvedBy, equals('mgr_tariq'));
    });

    test('P111: Branch Manager cannot approve device from different branch (ERR_CROSS_BRANCH_VIOLATION)', () {
      final gulshanDevice = ownerClient.registerDevice(
        branchId: 'br-gulshan-02',
        deviceId: 'term-pos-gulshan-01',
        deviceLabel: 'Counter 1 - Gulshan Desk',
        publicKeyPem: sampleEd25519Pub,
      );

      managerBranch1Client.importRegistration(gulshanDevice);

      expect(
        () => managerBranch1Client.approveDevice(gulshanDevice.registrationId),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_CROSS_BRANCH_VIOLATION'),
        )),
      );
    });

    test('P111: Cashier is strictly denied approval authority (ERR_PERMISSION_DENIED)', () {
      final reg = ownerClient.registerDevice(
        branchId: 'br-dhanmondi-01',
        deviceId: 'term-pos-cashier-test',
        deviceLabel: 'Cashier Terminal',
        publicKeyPem: sampleEd25519Pub,
      );

      cashierClient.importRegistration(reg);

      expect(
        () => cashierClient.approveDevice(reg.registrationId),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_PERMISSION_DENIED'),
        )),
      );
    });

    test('P111: Rejection and revocation require mandatory reason', () {
      final reg1 = ownerClient.registerDevice(
        branchId: 'br-dhanmondi-01',
        deviceId: 'term-rogue-01',
        deviceLabel: 'Rogue Workstation',
        publicKeyPem: sampleEd25519Pub,
      );

      expect(
        () => ownerClient.rejectDevice(reg1.registrationId, reason: '   '),
        throwsArgumentError,
      );

      final rejected = ownerClient.rejectDevice(
        reg1.registrationId,
        reason: 'Unregistered MAC address',
      );
      expect(rejected.status, equals('REJECTED'));
      expect(rejected.rejectionReason, equals('Unregistered MAC address'));

      final reg2 = ownerClient.registerDevice(
        branchId: 'br-dhanmondi-01',
        deviceId: 'term-stolen-01',
        deviceLabel: 'Stolen Workstation',
        publicKeyPem: sampleEd25519Pub,
      );
      ownerClient.approveDevice(reg2.registrationId);

      expect(
        () => ownerClient.revokeDevice(reg2.registrationId, reason: ''),
        throwsArgumentError,
      );

      final revoked = ownerClient.revokeDevice(
        reg2.registrationId,
        reason: 'Workstation stolen from store',
      );
      expect(revoked.status, equals('REVOKED'));
      expect(revoked.revocationReason, equals('Workstation stolen from store'));
    });

    test('P111: Verification challenge accurately validates trust, approval states, and key mismatch', () {
      final reg = ownerClient.registerDevice(
        branchId: 'br-dhanmondi-01',
        deviceId: 'term-gate-01',
        deviceLabel: 'Gate Test Terminal',
        publicKeyPem: sampleEd25519Pub,
      );

      // 1. Pending approval
      final res1 = ownerClient.verifyDevice('term-gate-01', publicKeyPem: sampleEd25519Pub);
      expect(res1.isTrusted, isFalse);
      expect(res1.errorCode, equals('ERR_DEVICE_NOT_APPROVED'));

      // 2. Approved matching key
      ownerClient.approveDevice(reg.registrationId);
      final res2 = ownerClient.verifyDevice('term-gate-01', publicKeyPem: sampleEd25519Pub);
      expect(res2.isTrusted, isTrue);
      expect(res2.status, equals('APPROVED'));

      // 3. Approved key mismatch
      final res3 = ownerClient.verifyDevice('term-gate-01', publicKeyPem: anotherEd25519Pub);
      expect(res3.isTrusted, isFalse);
      expect(res3.errorCode, equals('ERR_DEVICE_KEY_MISMATCH'));

      // 4. Revoked
      ownerClient.revokeDevice(reg.registrationId, reason: 'Compromised');
      final res4 = ownerClient.verifyDevice('term-gate-01', publicKeyPem: sampleEd25519Pub);
      expect(res4.isTrusted, isFalse);
      expect(res4.errorCode, equals('ERR_DEVICE_REVOKED'));

      // 5. Unknown
      final res5 = ownerClient.verifyDevice('term-nonexistent');
      expect(res5.isTrusted, isFalse);
      expect(res5.errorCode, equals('ERR_DEVICE_NOT_FOUND'));
    });

    test('P111: Update device label, offline queuing, and synchronization', () {
      final reg = ownerClient.registerDevice(
        branchId: 'br-dhanmondi-01',
        deviceId: 'term-sync-01',
        deviceLabel: 'Original Label',
        publicKeyPem: sampleEd25519Pub,
      );

      final updated = ownerClient.updateDeviceLabel(reg.registrationId, 'Counter 1 - Fast Track');
      expect(updated.deviceLabel, equals('Counter 1 - Fast Track'));

      // Offline mode
      ownerClient.setOffline(true);
      ownerClient.registerDevice(
        branchId: 'br-dhanmondi-01',
        deviceId: 'term-offline-01',
        deviceLabel: 'Offline Terminal',
        publicKeyPem: sampleEd25519Pub,
      );

      final uiState = ownerClient.getUiState();
      expect(uiState.uiStatus, equals(MobileDeviceUiStatus.offline));
      expect(uiState.offlineQueueCount, equals(1));

      final synced = ownerClient.syncOfflineRegistrations();
      expect(synced, equals(1));

      ownerClient.setOffline(false);
      final onlineState = ownerClient.getUiState();
      expect(onlineState.uiStatus, equals(MobileDeviceUiStatus.success));
      expect(onlineState.offlineQueueCount, equals(0));
    });
  });
}

