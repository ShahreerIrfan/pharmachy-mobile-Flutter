import 'package:flutter_test/flutter_test.dart';
import 'package:pharmacy_mobile_manager/core/security/mobile_active_sessions_client.dart';

void main() {
  group('P112: MobileActiveSessionsClient Tests', () {
    late MobileActiveSessionsClient ownerClient;
    late MobileActiveSessionsClient managerDhanmondiClient;
    late MobileActiveSessionsClient cashierClient;

    late MobileActiveSessionRecord ownerSession;
    late MobileActiveSessionRecord dhanmondiStaffSession;
    late MobileActiveSessionRecord gulshanStaffSession;
    late MobileActiveSessionRecord foreignTenantSession;

    setUp(() {
      ownerClient = MobileActiveSessionsClient(
        baseUrl: 'http://localhost:8000/api/v2',
        tenantId: 'tn-lazz-pharma',
        userRole: 'PHARMACY_OWNER',
        userId: 'usr-owner-01',
        userEmail: 'owner@lazz.local',
        currentSessionId: 'sess-owner-current',
      );

      managerDhanmondiClient = MobileActiveSessionsClient(
        baseUrl: 'http://localhost:8000/api/v2',
        tenantId: 'tn-lazz-pharma',
        userRole: 'BRANCH_MANAGER',
        userBranchId: 'br-dhanmondi-01',
        userId: 'usr-mgr-01',
        userEmail: 'mgr@lazz.local',
        currentSessionId: 'sess-mgr-current',
      );

      cashierClient = MobileActiveSessionsClient(
        baseUrl: 'http://localhost:8000/api/v2',
        tenantId: 'tn-lazz-pharma',
        userRole: 'CASHIER',
        userBranchId: 'br-dhanmondi-01',
        userId: 'usr-csh-01',
        userEmail: 'csh@lazz.local',
        currentSessionId: 'sess-csh-current',
      );

      ownerSession = const MobileActiveSessionRecord(
        sessionId: 'sess-owner-current',
        userId: 'usr-owner-01',
        userEmail: 'owner@lazz.local',
        userFullName: 'Kabir Ahmed',
        userRole: 'PHARMACY_OWNER',
        tenantId: 'tn-lazz-pharma',
        deviceId: 'dev-owner-iphone',
        deviceName: 'Owner iPhone 15 Pro',
        clientPlatform: 'MOBILE_MANAGER',
        ipAddress: '192.168.1.10',
        isActive: true,
        isCurrent: true,
        lastSeenAt: '2026-11-02T10:00:00Z',
        createdAt: '2026-11-02T08:00:00Z',
      );

      dhanmondiStaffSession = const MobileActiveSessionRecord(
        sessionId: 'sess-dhanmondi-csh',
        userId: 'usr-csh-01',
        userEmail: 'csh@lazz.local',
        userFullName: 'Rahim Uddin',
        userRole: 'CASHIER',
        tenantId: 'tn-lazz-pharma',
        branchId: 'br-dhanmondi-01',
        deviceId: 'pos-counter-01',
        deviceName: 'Counter 1 Desk',
        clientPlatform: 'DESKTOP_POS',
        ipAddress: '192.168.1.50',
        isActive: true,
        isCurrent: false,
        lastSeenAt: '2026-11-02T10:05:00Z',
        createdAt: '2026-11-02T08:30:00Z',
      );

      gulshanStaffSession = const MobileActiveSessionRecord(
        sessionId: 'sess-gulshan-csh',
        userId: 'usr-csh-gulshan',
        userEmail: 'csh_gulshan@lazz.local',
        userFullName: 'Karim Sheikh',
        userRole: 'CASHIER',
        tenantId: 'tn-lazz-pharma',
        branchId: 'br-gulshan-02',
        deviceId: 'pos-counter-gulshan',
        deviceName: 'Gulshan Counter Desk',
        clientPlatform: 'DESKTOP_POS',
        ipAddress: '192.168.2.50',
        isActive: true,
        isCurrent: false,
        lastSeenAt: '2026-11-02T10:02:00Z',
        createdAt: '2026-11-02T09:00:00Z',
      );

      foreignTenantSession = const MobileActiveSessionRecord(
        sessionId: 'sess-foreign-tenant',
        userId: 'usr-foreign-01',
        userEmail: 'foreign@popular.local',
        userFullName: 'Foreign User',
        userRole: 'PHARMACY_OWNER',
        tenantId: 'tn-popular-pharma',
        branchId: 'br-foreign-01',
        deviceId: 'pos-foreign-01',
        deviceName: 'Popular Counter',
        clientPlatform: 'DESKTOP_POS',
        ipAddress: '10.0.0.1',
        isActive: true,
        isCurrent: false,
        lastSeenAt: '2026-11-02T10:00:00Z',
        createdAt: '2026-11-02T08:00:00Z',
      );

      for (final c in [ownerClient, managerDhanmondiClient, cashierClient]) {
        c.importSession(ownerSession);
        c.importSession(dhanmondiStaffSession);
        c.importSession(gulshanStaffSession);
        c.importSession(foreignTenantSession);
      }
    });

    test('P112: Pharmacy Owner sees all active sessions across branches in their tenant', () {
      final sessions = ownerClient.listSessions(activeOnly: true);
      expect(sessions.length, equals(3));

      final emails = sessions.map((s) => s.userEmail).toList();
      expect(emails, contains('owner@lazz.local'));
      expect(emails, contains('csh@lazz.local'));
      expect(emails, contains('csh_gulshan@lazz.local'));
    });

    test('P112: Branch Manager is strictly scoped to assigned branch sessions', () {
      final sessions = managerDhanmondiClient.listSessions(activeOnly: true);
      expect(sessions.length, equals(1));
      expect(sessions.first.sessionId, equals('sess-dhanmondi-csh'));
      expect(sessions.first.branchId, equals('br-dhanmondi-01'));
    });

    test('P112: Cashier is strictly restricted to self-only session listing', () {
      final sessions = cashierClient.listSessions(activeOnly: true);
      expect(sessions.length, equals(1));
      expect(sessions.first.userId, equals('usr-csh-01'));
      expect(sessions.first.userEmail, equals('csh@lazz.local'));
    });

    test('P112: Pharmacy Owner can revoke any staff session in their tenant', () {
      final res = ownerClient.revokeSession('sess-dhanmondi-csh', reason: 'Terminated cashier station');
      expect(res.revoked, isTrue);
      expect(res.status, equals('SUCCESS'));

      final active = ownerClient.listSessions(activeOnly: true);
      expect(active.any((s) => s.sessionId == 'sess-dhanmondi-csh'), isFalse);
    });

    test('P112: Branch Manager can revoke session of staff in their branch', () {
      final res = managerDhanmondiClient.revokeSession('sess-dhanmondi-csh', reason: 'Closed shift');
      expect(res.revoked, isTrue);
      expect(res.status, equals('SUCCESS'));
    });

    test('P112: Branch Manager cannot revoke session in another branch (ERR_CROSS_BRANCH_VIOLATION)', () {
      expect(
        () => managerDhanmondiClient.revokeSession('sess-gulshan-csh', reason: 'Cross-branch revoke'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_CROSS_BRANCH_VIOLATION'),
        )),
      );
    });

    test('P112: Cashier cannot revoke another user\'s session (ERR_PERMISSION_DENIED)', () {
      expect(
        () => cashierClient.revokeSession('sess-owner-current', reason: 'Rogue cashier revoke'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_PERMISSION_DENIED'),
        )),
      );
    });

    test('P112: Cross-tenant session revocation is strictly denied (ERR_CROSS_TENANT_VIOLATION)', () {
      expect(
        () => ownerClient.revokeSession('sess-foreign-tenant', reason: 'Cross-tenant attempt'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ERR_CROSS_TENANT_VIOLATION'),
        )),
      );
    });

    test('P112: Owner bulk-revokes all active sessions for a staff member', () {
      final res = ownerClient.revokeAllSessions(
        targetUserId: 'usr-csh-01',
        reason: 'Compromised staff credential',
      );
      expect(res.status, equals('SUCCESS'));
      expect(res.revokedCount, equals(1));
      expect(res.targetUserId, equals('usr-csh-01'));
    });

    test('P112: Offline mode queues revocations locally, reports OFFLINE UI status, and syncs upon reconnection', () {
      final offlineClient = MobileActiveSessionsClient(
        baseUrl: 'http://localhost:8000/api/v2',
        tenantId: 'tn-lazz-pharma',
        userRole: 'PHARMACY_OWNER',
        userId: 'usr-owner-01',
        userEmail: 'owner@lazz.local',
        currentSessionId: 'sess-owner-current',
      );
      offlineClient.importSession(dhanmondiStaffSession);
      offlineClient.setOffline(true);

      final res = offlineClient.revokeSession('sess-dhanmondi-csh', reason: 'Offline revoke');
      expect(res.revoked, isTrue);
      expect(res.status, equals('OFFLINE_QUEUED'));

      final uiState = offlineClient.getUiState();
      expect(uiState.uiStatus, equals(MobileActiveSessionsUiStatus.offline));
      expect(uiState.offlineQueueCount, equals(1));

      final synced = offlineClient.syncOfflineRevocations();
      expect(synced, equals(1));

      offlineClient.setOffline(false);
      final onlineState = offlineClient.getUiState();
      expect(onlineState.uiStatus, equals(MobileActiveSessionsUiStatus.success));
      expect(onlineState.offlineQueueCount, equals(0));
    });
  });
}

