// test/core/security/mobile_staff_offline_auth_client_test.dart
// Unit tests for P113 MobileStaffOfflineAuthClient (ADR-0113).

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_staff_offline_auth_client.dart';

void main() {
  group('P113: MobileStaffOfflineAuthClient Tests', () {
    const localDeviceId = 'dev-manager-ipad-01';
    late MobileStaffOfflineAuthClient client;

    setUp(() {
      client = MobileStaffOfflineAuthClient(localDeviceId: localDeviceId);
    });

    MobileStaffOfflineRecord createSampleRecord({
      String role = 'CASHIER',
      DateTime? expiresAt,
      bool isRevoked = false,
      String? deviceId,
    }) {
      return MobileStaffOfflineRecord(
        authorizationId: 'oath-m101',
        tenantId: 'tn-lazz-dhaka',
        branchId: 'br-dhanmondi-01',
        staffId: 'staff-cashier-01',
        username: 'cashier01',
        fullName: 'Rahim Cashier',
        role: role,
        deviceId: deviceId ?? localDeviceId,
        credentialSalt: 'salt-hex-1234',
        credentialHash: 'hash-hex-5678',
        permittedActions: const ['pos.sale.create', 'pos.sale.view', 'pos.receipt.print'],
        deniedActions: const ['pos.refund.process', 'pos.discount.override'],
        riskLimits: const MobileRiskLimits(
          maxOfflineDiscountPercent: 5.0,
          maxOfflineSaleAmount: 25000.0,
          allowCreditSales: false,
          requireSupervisorRefund: true,
        ),
        issuedAt: DateTime.now().subtract(const Duration(hours: 1)),
        expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 48)),
        signature: 'dummy-signature',
        isRevoked: isRevoked,
      );
    }

    test('P113: Valid offline staff verification succeeds with offline UI status', () {
      final record = createSampleRecord();
      client.cacheAuthorization(record);

      final result = client.verifyOffline(
        staffId: 'staff-cashier-01',
        pin: '1234',
        verificationTime: DateTime.now(),
      );

      expect(result.isAuthorized, isTrue);
      expect(result.uiStatus, equals(MobileStaffOfflineUiStatus.offline));
      expect(result.username, equals('cashier01'));
      expect(result.role, equals('CASHIER'));
    });

    test('P113: Device ID mismatch fails with ERR_OFFLINE_DEVICE_MISMATCH', () {
      final record = createSampleRecord(deviceId: 'dev-other-station');
      client.cacheAuthorization(record);

      final result = client.verifyOffline(
        staffId: 'staff-cashier-01',
        pin: '1234',
      );

      expect(result.isAuthorized, isFalse);
      expect(result.errorCode, equals('ERR_OFFLINE_DEVICE_MISMATCH'));
    });

    test('P113: Expired offline authorization fails with ERR_OFFLINE_AUTH_EXPIRED', () {
      final past = DateTime.now().subtract(const Duration(hours: 2));
      final record = createSampleRecord(expiresAt: past);
      client.cacheAuthorization(record);

      final result = client.verifyOffline(
        staffId: 'staff-cashier-01',
        pin: '1234',
      );

      expect(result.isAuthorized, isFalse);
      expect(result.errorCode, equals('ERR_OFFLINE_AUTH_EXPIRED'));
    });

    test('P113: Revoked offline authorization fails with ERR_STAFF_ROLE_DENIED', () {
      final record = createSampleRecord(isRevoked: true);
      client.cacheAuthorization(record);

      final result = client.verifyOffline(
        staffId: 'staff-cashier-01',
        pin: '1234',
      );

      expect(result.isAuthorized, isFalse);
      expect(result.errorCode, equals('ERR_STAFF_ROLE_DENIED'));
    });

    test('P113: Risk limits enforce discount and transaction caps', () {
      final record = createSampleRecord();
      client.cacheAuthorization(record);

      expect(client.isDiscountPermitted('staff-cashier-01', 5.0), isTrue);
      expect(client.isDiscountPermitted('staff-cashier-01', 5.5), isFalse);

      expect(client.isSaleAmountPermitted('staff-cashier-01', 25000.0), isTrue);
      expect(client.isSaleAmountPermitted('staff-cashier-01', 25000.1), isFalse);

      expect(client.canPerformAction('staff-cashier-01', 'pos.sale.create'), isTrue);
      expect(client.canPerformAction('staff-cashier-01', 'pos.refund.process'), isFalse);
    });
  });
}

