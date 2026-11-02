// test/core/staff/mobile_staff_lifecycle_client_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/staff/mobile_staff_lifecycle_client.dart';

void main() {
  group('P106: MobileStaffLifecycleClient Tests', () {
    late MobileStaffLifecycleClient client;

    setUp(() {
      client = MobileStaffLifecycleClient();
    });

    test('P106: Owner successfully validates direct staff onboarding', () {
      final res = client.validateDirectCreation(
        tenantId: 'tenant-test-1',
        username: 'jamal_rx',
        email: 'jamal@example.com',
        fullName: 'Jamal Ahmed',
        role: 'STAFF_PHARMACIST',
        actorRole: 'PHARMACY_OWNER',
      );
      expect(res.isValid, isTrue);
      expect(res.errorCode, isEmpty);
    });

    test('P106: Cashier is forbidden from creating staff accounts (RBAC gate)', () {
      final res = client.validateDirectCreation(
        tenantId: 'tenant-test-1',
        username: 'new_staff',
        email: 'new@example.com',
        fullName: 'New Staff',
        role: 'CASHIER',
        actorRole: 'CASHIER',
      );
      expect(res.isValid, isFalse);
      expect(res.errorCode, 'ERR_PERMISSION_DENIED');
      expect(res.messageBn.contains('মালিক'), isTrue);
    });

    test('P106: Invalid email or short full name fails validation', () {
      final badEmail = client.validateDirectCreation(
        tenantId: 'tenant-test-1',
        username: 'good_user',
        email: 'not-an-email',
        fullName: 'Good Name',
        role: 'CASHIER',
        actorRole: 'PHARMACY_OWNER',
      );
      expect(badEmail.isValid, isFalse);
      expect(badEmail.errorCode, 'ERR_INVALID_EMAIL');

      final shortName = client.validateDirectCreation(
        tenantId: 'tenant-test-1',
        username: 'good_user',
        email: 'valid@example.com',
        fullName: 'X',
        role: 'CASHIER',
        actorRole: 'PHARMACY_OWNER',
      );
      expect(shortName.isValid, isFalse);
      expect(shortName.errorCode, 'ERR_INVALID_FULL_NAME');
    });

    test('P106: Termination requires detailed reason and owner permissions', () {
      final shortReason = client.validateTermination(
        staffId: 'stf-001',
        reason: 'no',
        actorRole: 'PHARMACY_OWNER',
      );
      expect(shortReason.isValid, isFalse);
      expect(shortReason.errorCode, 'ERR_TERMINATION_REASON_REQUIRED');

      final unauthorized = client.validateTermination(
        staffId: 'stf-001',
        reason: 'Valid termination reason',
        actorRole: 'STAFF_PHARMACIST',
      );
      expect(unauthorized.isValid, isFalse);
      expect(unauthorized.errorCode, 'ERR_PERMISSION_DENIED');

      final ok = client.validateTermination(
        staffId: 'stf-001',
        reason: 'Resigned due to personal reasons',
        actorRole: 'PHARMACY_OWNER',
      );
      expect(ok.isValid, isTrue);
    });

    test('P106: Deactivation and termination transitions update status and clear sessions', () {
      const record = MobileStaffLifecycleRecord(
        staffId: 'stf-101',
        tenantId: 'tenant-test-1',
        branchId: 'br-01',
        branchName: 'Dhanmondi Branch',
        username: 'staff_101',
        email: 'staff101@example.com',
        fullName: 'Staff 101',
        role: 'CASHIER',
        mobileNumber: '+8801700000000',
        pcbRegistrationNo: '',
        lifecycleStatus: 'ACTIVE',
        isActive: true,
        mfaEnabled: true,
        activeSessionsCount: 4,
        activeLeasesCount: 1,
        createdAt: '2026-01-01T00:00:00Z',
      );

      final deactState = client.applyDeactivation(record, 'Administrative inquiry', 'owner_kamal');
      expect(deactState.status, MobileStaffLifecycleUiStatus.success);
      expect(deactState.record?.lifecycleStatus, 'DEACTIVATED');
      expect(deactState.record?.isActive, isFalse);
      expect(deactState.record?.activeSessionsCount, 0);

      final termState = client.applyTermination(record, 'Permanent employment termination', 'owner_kamal');
      expect(termState.status, MobileStaffLifecycleUiStatus.success);
      expect(termState.record?.lifecycleStatus, 'TERMINATED');
      expect(termState.record?.isActive, isFalse);
      expect(termState.record?.mfaEnabled, isFalse);
      expect(termState.record?.activeSessionsCount, 0);
      expect(termState.record?.activeLeasesCount, 0);
    });

    test('P106: Offline fallback returns cached profile with translated guidance', () {
      const record = MobileStaffLifecycleRecord(
        staffId: 'stf-cache-1',
        tenantId: 'tenant-test-1',
        username: 'cached_mobile_staff',
        fullName: 'Cached Staff',
        role: 'CASHIER',
        mobileNumber: '+8801700000000',
        pcbRegistrationNo: '',
        lifecycleStatus: 'ACTIVE',
        isActive: true,
        mfaEnabled: false,
        activeSessionsCount: 1,
        activeLeasesCount: 0,
        createdAt: '2026-01-01T00:00:00Z',
      );
      client.cacheRecord(record);

      final state = client.toOfflineState('stf-cache-1');
      expect(state.status, MobileStaffLifecycleUiStatus.offline);
      expect(state.isOffline, isTrue);
      expect(state.record?.username, 'cached_mobile_staff');
      expect(state.errorMessageBn.contains('অফলাইন'), isTrue);
    });
  });
}
